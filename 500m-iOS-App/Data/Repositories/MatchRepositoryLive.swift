import Combine
import FirebaseFirestore
import Foundation

final class MatchRepositoryLive: MatchRepository {
    private let firestore: Firestore
    private let historyRepository: UserHistoryRepository
    private let partnerRepository: PartnerRepository

    init(
        firestore: Firestore = Firestore.firestore(),
        historyRepository: UserHistoryRepository,
        partnerRepository: PartnerRepository
    ) {
        self.firestore = firestore
        self.historyRepository = historyRepository
        self.partnerRepository = partnerRepository
    }

    func requestMatch(
        marketId: String,
        serviceType: ServiceType,
        userId: String,
        driverId: String,
        pickupLat: Double,
        pickupLng: Double,
        memo: String?
    ) async throws -> String {
        let ref = firestore.collection("matchRequests").document()
        try await FirebaseAsync.setData(ref, data: [
            "marketId": marketId,
            "serviceType": serviceType.rawValue,
            "userId": userId,
            "driverId": driverId,
            "pickupLat": pickupLat,
            "pickupLng": pickupLng,
            "memo": memo as Any,
            "status": MatchRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await syncHistory(from: ref.documentID)
        return ref.documentID
    }

    func observeMyPendingRequests(driverId: String, marketId: String, serviceType: ServiceType) -> AnyPublisher<[MatchRequest], Never> {
        let subject = PassthroughSubject<[MatchRequest], Never>()
        let listener = firestore.collection("matchRequests")
            .whereField("driverId", isEqualTo: driverId)
            .whereField("marketId", isEqualTo: marketId)
            .whereField("serviceType", isEqualTo: serviceType.rawValue)
            .whereField("status", in: [
                MatchRequestStatus.pending.rawValue,
                MatchRequestStatus.accepted.rawValue,
                MatchRequestStatus.inProgress.rawValue
            ])
            .addSnapshotListener { snapshot, _ in
                let items = snapshot?.documents.map { FirestoreMappers.matchRequest(from: $0.data(), id: $0.documentID) } ?? []
                subject.send(items.sorted { $0.createdAt > $1.createdAt })
            }
        return subject.handleEvents(receiveCancel: { listener.remove() }).eraseToAnyPublisher()
    }

    func acceptRequest(requestId: String) async throws { try await updateStatus(requestId: requestId, status: .accepted) }
    func rejectRequest(requestId: String) async throws { try await updateStatus(requestId: requestId, status: .rejected) }
    func startRide(requestId: String) async throws { try await updateStatus(requestId: requestId, status: .inProgress) }
    func completeRide(requestId: String) async throws { try await updateStatus(requestId: requestId, status: .completed) }
    func cancelRequest(requestId: String) async throws { try await updateStatus(requestId: requestId, status: .canceled) }

    func observeMatchRequest(requestId: String) -> AnyPublisher<MatchRequest?, Never> {
        let subject = PassthroughSubject<MatchRequest?, Never>()
        let listener = firestore.collection("matchRequests").document(requestId)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot, let data = snapshot.data() else {
                    subject.send(nil)
                    return
                }
                subject.send(FirestoreMappers.matchRequest(from: data, id: requestId))
            }
        return subject.handleEvents(receiveCancel: { listener.remove() }).eraseToAnyPublisher()
    }

    func expireIfPending(requestId: String) async throws {
        let ref = firestore.collection("matchRequests").document(requestId)
        let snapshot = try await FirebaseAsync.getDocument(ref)
        guard
            let data = snapshot.data(),
            MatchRequestStatus(rawValue: data["status"] as? String ?? "") == .pending
        else { return }
        try await updateStatus(requestId: requestId, status: .expired)
    }

    private func updateStatus(requestId: String, status: MatchRequestStatus) async throws {
        let ref = firestore.collection("matchRequests").document(requestId)
        var data: [AnyHashable: Any] = ["status": status.rawValue]
        switch status {
        case .accepted:
            data["acceptedAt"] = FieldValue.serverTimestamp()
        case .inProgress:
            data["startedAt"] = FieldValue.serverTimestamp()
        case .completed:
            data["endedAt"] = FieldValue.serverTimestamp()
        default:
            break
        }
        try await FirebaseAsync.updateData(ref, data: data)
        try await syncHistory(from: requestId)
    }

    private func syncHistory(from requestId: String) async throws {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("matchRequests").document(requestId))
        guard let data = snapshot.data() else { return }
        let request = FirestoreMappers.matchRequest(from: data, id: requestId)
        let provider = try await providerSnapshot(driverId: request.driverId, serviceType: request.serviceType)
        let item = UserHistoryItem(
            requestId: request.id,
            service: request.serviceType,
            status: request.status,
            marketId: request.marketId,
            createdAtMs: request.createdAt,
            expireAtMs: request.createdAt + 90 * 24 * 60 * 60 * 1000,
            providerId: request.driverId,
            providerName: provider.0,
            providerProfileImageURL: provider.1,
            pickupLat: request.pickupLat,
            pickupLng: request.pickupLng
        )
        await historyRepository.upsertHistoryItem(uid: request.userId, item: item)
    }

    private func providerSnapshot(driverId: String, serviceType: ServiceType) async throws -> (String?, String?) {
        switch serviceType {
        case .taxi:
            let driver = try await partnerRepository.getTaxiDriver(driverId: driverId)
            return (driver?.name, driver?.photoURL)
        case .daeri:
            let driver = try await partnerRepository.getDaeriDriver(driverId: driverId)
            return (driver?.name, driver?.photoURL)
        case .store:
            return (nil, nil)
        }
    }
}
