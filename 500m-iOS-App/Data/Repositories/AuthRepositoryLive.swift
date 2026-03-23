import FirebaseAuth
import FirebaseFunctions
import Foundation
import GoogleSignIn
import KakaoSDKAuth
import KakaoSDKUser
import UIKit

private struct KakaoCustomTokenRequest: Encodable {
    let kakaoAccessToken: String
}

private struct KakaoCustomTokenResponse: Decodable {
    let customToken: String
}

final class AuthRepositoryLive: AuthRepository {
    private let environment: AppEnvironment

    init(environment: AppEnvironment = .shared) {
        self.environment = environment
    }

    @MainActor
    func signInWithGoogle() async throws -> AuthUser {
        guard let presenter = TopViewControllerFinder.topViewController() else {
            throw DataLayerError.notConfigured("Google presenter")
        }

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: DataLayerError.notConfigured("Google sign-in result"))
                }
            }
        }

        guard
            let idToken = result.user.idToken?.tokenString
        else {
            throw DataLayerError.notConfigured("Google ID token")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await FirebaseAsync.signIn(with: credential)
        return Self.makeAuthUser(authResult.user)
    }

    @MainActor
    func signInWithKakao() async throws -> AuthUser {
        let oauthToken = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OAuthToken, Error>) in
            let callback: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: DataLayerError.notConfigured("Kakao OAuth token"))
                }
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: callback)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: callback)
            }
        }

        let url = environment.kakaoFunctionsBaseURL.appendingPathComponent("authKakao")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(KakaoCustomTokenRequest(kakaoAccessToken: oauthToken.accessToken))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw DataLayerError.notConfigured("Kakao custom token exchange")
        }

        let customToken = try JSONDecoder().decode(KakaoCustomTokenResponse.self, from: data).customToken
        let authResult = try await FirebaseAsync.signIn(withCustomToken: customToken)
        return Self.makeAuthUser(authResult.user)
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        UserApi.shared.logout { _ in }
    }

    func requireUID() async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw DomainError.unauthenticated
        }
        return uid
    }

    func deleteMyAccount() async throws {
        let functions = Functions.functions(region: environment.firebaseFunctionsRegion)
        _ = try await FirebaseAsync.call(function: functions.httpsCallable("deleteMyAccount"))
    }

    private static func makeAuthUser(_ user: FirebaseAuth.User) -> AuthUser {
        AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString
        )
    }
}
