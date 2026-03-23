import FirebaseFirestore
import FirebaseStorage
import Foundation

final class PartnerApplicationRepositoryLive: PartnerApplicationRepository {
    private let firestore: Firestore
    private let storage: Storage

    init(
        firestore: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage()
    ) {
        self.firestore = firestore
        self.storage = storage
    }

    func getApplication(applicationId: String) async throws -> PartnerApplication? {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("partnerApplications").document(applicationId))
        guard let data = snapshot.data() else { return nil }
        return FirestoreMappers.partnerApplication(from: data, id: applicationId)
    }

    func upsertApplication(_ application: PartnerApplication) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("partnerApplications").document(application.id),
            data: [
                "applicationId": application.id,
                "uid": application.uid,
                "mode": application.mode.rawValue,
                "marketId": application.marketId,
                "status": application.status.rawValue,
                "partnerId": application.partnerId as Any,
                "payload": application.payload,
                "attachments": application.attachments,
                "createdAt": application.createdAt,
                "updatedAt": application.updatedAt,
                "reviewedAt": application.reviewedAt,
                "reviewedBy": application.reviewedBy as Any,
                "rejectReason": application.rejectReason as Any
            ],
            merge: true
        )
    }

    func uploadPartnerDocument(uid: String, data: Data, ext: String) async throws -> String {
        let ref = storage.reference().child("partner_applications/\(uid)/docs/\(UUID().uuidString).\(ext)")
        return try await FirebaseAsync.downloadURL(afterUploading: data, to: ref).absoluteString
    }
}
