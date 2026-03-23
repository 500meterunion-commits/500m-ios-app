import Combine
import FirebaseFirestore
import Foundation

final class UserHistoryRepositoryLive: UserHistoryRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func observeHistory(uid: String, service: ServiceType?) -> AnyPublisher<[UserHistoryItem], Never> {
        let subject = PassthroughSubject<[UserHistoryItem], Never>()
        var query: Query = firestore.collection("users").document(uid).collection("history")
        if let service {
            query = query.whereField("service", isEqualTo: service.rawValue)
        }
        let listener = query.addSnapshotListener { snapshot, _ in
            let items = snapshot?.documents.map {
                FirestoreMappers.userHistoryItem(from: $0.data(), id: $0.documentID)
            } ?? []
            subject.send(items.sorted { $0.createdAtMs > $1.createdAtMs })
        }

        return subject.handleEvents(receiveCancel: {
            listener.remove()
        }).eraseToAnyPublisher()
    }

    func upsertHistoryItem(uid: String, item: UserHistoryItem) async {
        let data: [String: Any] = [
            "service": item.service.rawValue,
            "status": item.status.rawValue,
            "marketId": item.marketId,
            "createdAtMs": item.createdAtMs,
            "expireAtMs": item.expireAtMs,
            "providerId": item.providerId as Any,
            "providerName": item.providerName as Any,
            "providerProfileImageUrl": item.providerProfileImageURL as Any,
            "pickupLat": item.pickupLat as Any,
            "pickupLng": item.pickupLng as Any
        ]
        try? await FirebaseAsync.setData(
            firestore.collection("users").document(uid).collection("history").document(item.id),
            data: data,
            merge: true
        )
    }
}
