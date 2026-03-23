import Combine
import Foundation

struct ObserveCachedUserProfileUseCase {
    let repository: UserRepository

    func callAsFunction() -> AnyPublisher<UserProfile?, Never> {
        repository.observeCachedProfile()
    }
}

struct SyncAndGetUserProfileUseCase {
    let repository: UserRepository

    func callAsFunction(uid: String, displayName: String?, photoURL: String?) async throws -> UserProfile {
        try await repository.syncAndGetProfile(uid: uid, displayName: displayName, photoURL: photoURL)
    }
}

struct UpdateUserProfileUseCase {
    let repository: UserRepository

    func callAsFunction(uid: String, patch: UserProfilePatch) async throws -> UserProfile {
        try await repository.updateProfile(uid: uid, patch: patch)
    }
}

struct UploadUserProfileImageUseCase {
    let repository: UserRepository

    func callAsFunction(uid: String, imageData: Data) async throws -> UserProfile {
        try await repository.uploadProfileImageAndUpdate(uid: uid, imageData: imageData)
    }
}

struct ObserveUserLocationUseCase {
    let repository: LocationRepository

    func callAsFunction() -> AnyPublisher<LatLng, Never> {
        repository.observeLocation()
    }
}
