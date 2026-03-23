import Combine
import FirebaseFirestore
import FirebaseStorage
import Foundation

final class UserRepositoryLive: UserRepository {
    private let firestore: Firestore
    private let storage: Storage
    private let profileSubject = CurrentValueSubject<UserProfile?, Never>(nil)

    init(
        firestore: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage()
    ) {
        self.firestore = firestore
        self.storage = storage
    }

    func getUserProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("users").document(uid))
        guard let data = snapshot.data() else { return nil }
        let profile = FirestoreMappers.userProfile(from: data, id: uid)
        profileSubject.send(profile)
        return profile
    }

    func upsertUserProfile(_ profile: UserProfile) async throws {
        let ref = firestore.collection("users").document(profile.id)
        var data = FirestoreMappers.userProfileData(profile)
        if (try await FirebaseAsync.getDocument(ref)).exists == false {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        try await FirebaseAsync.setData(ref, data: data, merge: true)
        profileSubject.send(profile)
    }

    func observeCachedProfile() -> AnyPublisher<UserProfile?, Never> {
        profileSubject.eraseToAnyPublisher()
    }

    func syncAndGetProfile(uid: String, displayName: String?, photoURL: String?) async throws -> UserProfile {
        if let remote = try await getUserProfile(uid: uid) {
            return remote
        }

        let created = UserProfile(
            id: uid,
            displayName: displayName,
            userProfileURL: photoURL
        )
        try await upsertUserProfile(created)
        return created
    }

    func uploadProfileImageAndUpdate(uid: String, imageData: Data) async throws -> UserProfile {
        let ref = storage.reference().child("user_profiles/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let url = try await FirebaseAsync.downloadURL(afterUploading: imageData, to: ref, metadata: metadata)
        return try await updateProfile(uid: uid, patch: UserProfilePatch(userProfileURL: url.absoluteString))
    }

    func updateProfile(uid: String, patch: UserProfilePatch) async throws -> UserProfile {
        guard let current = try await getUserProfile(uid: uid) else {
            throw DomainError.notFound("UserProfile \(uid)")
        }

        let updated = UserProfile(
            id: uid,
            displayName: patch.displayName ?? current.displayName,
            marketId: patch.marketId ?? current.marketId,
            mode: patch.mode ?? current.mode,
            taxiAccess: patch.taxiAccess ?? current.taxiAccess,
            daeriAccess: patch.daeriAccess ?? current.daeriAccess,
            storeAccess: patch.storeAccess ?? current.storeAccess,
            taxiPartnerId: patch.taxiPartnerId ?? current.taxiPartnerId,
            daeriPartnerId: patch.daeriPartnerId ?? current.daeriPartnerId,
            storePartnerId: patch.storePartnerId ?? current.storePartnerId,
            userProfileURL: patch.userProfileURL ?? current.userProfileURL,
            agreedNormalTerms: patch.agreedNormalTerms ?? current.agreedNormalTerms,
            agreedPartnerTerms: patch.agreedPartnerTerms ?? current.agreedPartnerTerms
        )
        try await upsertUserProfile(updated)
        return updated
    }

    func clearLocal() async {
        profileSubject.send(nil)
    }
}
