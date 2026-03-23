import FirebaseFirestore
import Foundation

final class DriverTokenRepositoryLive: DriverTokenRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func registerToken(
        driverId: String,
        token: String,
        marketId: String,
        serviceType: ServiceType
    ) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("driverTokens").document(driverId),
            data: [
                "token": token,
                "platform": "ios",
                "marketId": marketId,
                "serviceType": serviceType.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    func unregisterToken(driverId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.collection("driverTokens").document(driverId).delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
