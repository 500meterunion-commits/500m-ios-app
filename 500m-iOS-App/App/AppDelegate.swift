import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import KakaoMapsSDK
import KakaoSDKCommon
import UIKit
import UserNotifications

extension Notification.Name {
    static let didUpdateFcmToken = Notification.Name("didUpdateFcmToken")
}

enum AppPushType: String, Sendable {
    case matchRequest = "MATCH_REQUEST"
    case matchAccepted = "MATCH_ACCEPTED"
    case matchRejected = "MATCH_REJECTED"
    case matchCanceled = "MATCH_CANCELED"
    case matchExpired = "MATCH_EXPIRED"
    case rideCompleted = "RIDE_COMPLETED"
    case partnerApplicationApproved = "PARTNER_APPLICATION_APPROVED"
    case partnerApplicationRejected = "PARTNER_APPLICATION_REJECTED"
}

struct MatchPushRoute: Equatable, Identifiable, Sendable {
    let type: AppPushType
    let requestId: String
    let marketId: String
    let serviceType: String

    var id: String {
        "\(type.rawValue):\(requestId):\(serviceType)"
    }
}

struct PartnerApplicationPushRoute: Equatable, Identifiable, Sendable {
    let type: AppPushType
    let applicationId: String
    let mode: String
    let rejectReason: String
    let marketId: String

    var id: String {
        "\(type.rawValue):\(applicationId):\(mode)"
    }
}

@MainActor
final class AppDeepLinkCenter: ObservableObject {
    static let shared = AppDeepLinkCenter()

    @Published private(set) var pendingMatchRoute: MatchPushRoute?
    @Published private(set) var pendingPartnerApplicationRoute: PartnerApplicationPushRoute?

    private init() { }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let rawType = userInfo["type"] as? String,
              let type = AppPushType(rawValue: rawType) else {
            return
        }

        switch type {
        case .matchRequest, .matchAccepted, .matchRejected, .matchCanceled, .matchExpired, .rideCompleted:
            pendingMatchRoute = MatchPushRoute(
                type: type,
                requestId: userInfo["requestId"] as? String ?? "",
                marketId: userInfo["marketId"] as? String ?? "",
                serviceType: userInfo["serviceType"] as? String ?? ""
            )
        case .partnerApplicationApproved, .partnerApplicationRejected:
            pendingPartnerApplicationRoute = PartnerApplicationPushRoute(
                type: type,
                applicationId: userInfo["applicationId"] as? String ?? "",
                mode: userInfo["mode"] as? String ?? "",
                rejectReason: userInfo["rejectReason"] as? String ?? "",
                marketId: userInfo["marketId"] as? String ?? ""
            )
        }
    }

    func consumeMatchRoute(_ route: MatchPushRoute?) {
        guard pendingMatchRoute == route else { return }
        pendingMatchRoute = nil
    }

    func consumePartnerRoute(_ route: PartnerApplicationPushRoute?) {
        guard pendingPartnerApplicationRoute == route else { return }
        pendingPartnerApplicationRoute = nil
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil, Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }

        let env = AppEnvironment.shared
        if !env.kakaoNativeAppKey.isEmpty {
            KakaoSDK.initSDK(appKey: env.kakaoNativeAppKey)
            SDKInitializer.InitSDK(appKey: env.kakaoNativeAppKey)
        }
        if !env.googleIOSClientID.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: env.googleIOSClientID,
                serverClientID: env.googleWebClientID.nilIfBlank
            )
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationAuthorization(application)

        if let remoteUserInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleRemoteUserInfo(remoteUserInfo)
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) { }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        handleRemoteUserInfo(userInfo)
        completionHandler(.newData)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let rawToken = fcmToken,
              let token = rawToken.nilIfBlank else { return }
        NotificationCenter.default.post(name: .didUpdateFcmToken, object: token)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleRemoteUserInfo(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleRemoteUserInfo(response.notification.request.content.userInfo)
        completionHandler()
    }

    private func requestNotificationAuthorization(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    private func handleRemoteUserInfo(_ userInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            AppDeepLinkCenter.shared.handleNotificationUserInfo(userInfo)
            if let typeString = userInfo["type"] as? String,
               AppPushType(rawValue: typeString) == .matchRequest,
               let requestId = (userInfo["requestId"] as? String)?.nilIfBlank {
                PendingMatchAutoExpireScheduler.shared.schedule(requestId: requestId)
            } else if let requestId = (userInfo["requestId"] as? String)?.nilIfBlank {
                PendingMatchAutoExpireScheduler.shared.cancel(requestId: requestId)
            }
        }
    }
}
