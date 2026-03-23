import Foundation

enum UserMode: String, Codable, Sendable {
    case general = "GENERAL"
    case partnerTaxi = "PARTNER_TAXI"
    case partnerDaeri = "PARTNER_DAERI"
    case partnerStore = "PARTNER_STORE"
}

enum ApprovalStatus: String, Codable, Sendable {
    case none = "NONE"
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

enum ServiceType: String, Codable, Sendable, CaseIterable {
    case taxi = "TAXI"
    case daeri = "DAERI"
    case store = "STORE"
}

enum MatchRequestStatus: String, Codable, Sendable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case rejected = "REJECTED"
    case canceled = "CANCELED"
    case expired = "EXPIRED"
}

enum PartnerApplicationStatus: String, Codable, Sendable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case canceled = "CANCELED"
}

struct LatLng: Codable, Equatable, Sendable {
    let lat: Double
    let lng: Double
}

struct RoutePolyline: Codable, Equatable, Sendable {
    let points: [LatLng]
    let distanceM: Int
    let durationSec: Int
}
