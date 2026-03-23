import Foundation

struct MatchRequest: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let marketId: String
    let serviceType: ServiceType
    let userId: String
    let driverId: String
    let pickupLat: Double
    let pickupLng: Double
    let createdAt: Int64
    let status: MatchRequestStatus
    let memo: String?

    init(
        requestId: String,
        marketId: String,
        serviceType: ServiceType,
        userId: String,
        driverId: String,
        pickupLat: Double,
        pickupLng: Double,
        createdAt: Int64,
        status: MatchRequestStatus,
        memo: String? = nil
    ) {
        self.id = requestId
        self.marketId = marketId
        self.serviceType = serviceType
        self.userId = userId
        self.driverId = driverId
        self.pickupLat = pickupLat
        self.pickupLng = pickupLng
        self.createdAt = createdAt
        self.status = status
        self.memo = memo
    }
}
