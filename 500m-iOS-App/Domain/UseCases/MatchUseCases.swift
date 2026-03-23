import Combine
import Foundation

struct RequestMatchUseCase {
    let repository: MatchRepository

    func callAsFunction(
        marketId: String,
        serviceType: ServiceType,
        userId: String,
        driverId: String,
        pickupLat: Double,
        pickupLng: Double,
        memo: String? = nil
    ) async throws -> String {
        try await repository.requestMatch(
            marketId: marketId,
            serviceType: serviceType,
            userId: userId,
            driverId: driverId,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            memo: memo
        )
    }
}

struct ObserveMatchRequestUseCase {
    let repository: MatchRepository

    func callAsFunction(requestId: String) -> AnyPublisher<MatchRequest?, Never> {
        repository.observeMatchRequest(requestId: requestId)
    }
}

struct ObserveDriverPendingRequestsUseCase {
    let repository: MatchRepository

    func callAsFunction(driverId: String, marketId: String, serviceType: ServiceType) -> AnyPublisher<[MatchRequest], Never> {
        repository.observeMyPendingRequests(driverId: driverId, marketId: marketId, serviceType: serviceType)
    }
}

struct AcceptMatchRequestUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.acceptRequest(requestId: requestId) }
}

struct RejectMatchRequestUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.rejectRequest(requestId: requestId) }
}

struct StartRideUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.startRide(requestId: requestId) }
}

struct CompleteRideUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.completeRide(requestId: requestId) }
}

struct CancelMatchRequestUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.cancelRequest(requestId: requestId) }
}

struct ExpireIfPendingUseCase {
    let repository: MatchRepository
    func callAsFunction(requestId: String) async throws { try await repository.expireIfPending(requestId: requestId) }
}
