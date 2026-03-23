import FirebaseFirestore
import Foundation

final class UserTokenRepositoryLive: UserTokenRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func registerUserToken(uid: String, token: String) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("userTokens").document(uid),
            data: [
                "token": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }
}
