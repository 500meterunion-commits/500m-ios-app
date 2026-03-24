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
        completionHandler([.banner, .sound, .badge])
    }

    private func requestNotificationAuthorization(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
}
