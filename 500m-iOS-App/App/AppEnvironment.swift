import Foundation

struct AppEnvironment {
    let kakaoNativeAppKey: String
    let kakaoRestAPIKey: String
    let kakaoFunctionsBaseURL: URL
    let googleIOSClientID: String
    let googleWebClientID: String
    let googleReversedClientID: String
    let firebaseFunctionsRegion: String

    static let shared = AppEnvironment(bundle: .main)

    init(bundle: Bundle) {
        self.kakaoNativeAppKey = bundle.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? ""
        self.kakaoRestAPIKey = bundle.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
        self.googleIOSClientID =
            bundle.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String
            ?? bundle.object(forInfoDictionaryKey: "GIDClientID") as? String
            ?? ""
        self.googleWebClientID = bundle.object(forInfoDictionaryKey: "GOOGLE_WEB_CLIENT_ID") as? String ?? ""
        self.googleReversedClientID = bundle.object(forInfoDictionaryKey: "GOOGLE_REVERSED_CLIENT_ID") as? String ?? ""
        self.firebaseFunctionsRegion = bundle.object(forInfoDictionaryKey: "FIREBASE_FUNCTIONS_REGION") as? String ?? "asia-northeast3"

        let baseURLString = bundle.object(forInfoDictionaryKey: "KAKAO_FUNCTIONS_BASE_URL") as? String
            ?? "https://asia-northeast3-m-ae6f5.cloudfunctions.net/"
        self.kakaoFunctionsBaseURL = URL(string: baseURLString) ?? URL(string: "https://asia-northeast3-m-ae6f5.cloudfunctions.net/")!
    }
}
