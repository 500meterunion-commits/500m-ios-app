import FirebaseCore
import GoogleSignIn
import KakaoMapsSDK
import KakaoSDKCommon
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
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
}
