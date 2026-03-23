import Foundation

struct SignInWithGoogleUseCase {
    let repository: AuthRepository

    func callAsFunction() async throws -> AuthUser {
        try await repository.signInWithGoogle()
    }
}

struct SignInWithKakaoUseCase {
    let repository: AuthRepository

    func callAsFunction() async throws -> AuthUser {
        try await repository.signInWithKakao()
    }
}

struct SignOutUseCase {
    let repository: AuthRepository

    func callAsFunction() async throws {
        try await repository.signOut()
    }
}

struct DeleteMyAccountUseCase {
    let repository: AuthRepository

    func callAsFunction() async throws {
        try await repository.deleteMyAccount()
    }
}
