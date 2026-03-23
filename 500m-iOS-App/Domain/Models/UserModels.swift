import Foundation

struct UserProfile: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String?
    let marketId: String?
    let mode: UserMode
    let taxiAccess: ApprovalStatus
    let daeriAccess: ApprovalStatus
    let storeAccess: ApprovalStatus
    let taxiPartnerId: String?
    let daeriPartnerId: String?
    let storePartnerId: String?
    let userProfileURL: String?
    let agreedNormalTerms: [String: Bool]?
    let agreedPartnerTerms: [String: Bool]?

    init(
        id: String,
        displayName: String? = nil,
        marketId: String? = nil,
        mode: UserMode = .general,
        taxiAccess: ApprovalStatus = .none,
        daeriAccess: ApprovalStatus = .none,
        storeAccess: ApprovalStatus = .none,
        taxiPartnerId: String? = nil,
        daeriPartnerId: String? = nil,
        storePartnerId: String? = nil,
        userProfileURL: String? = nil,
        agreedNormalTerms: [String: Bool]? = nil,
        agreedPartnerTerms: [String: Bool]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.marketId = marketId
        self.mode = mode
        self.taxiAccess = taxiAccess
        self.daeriAccess = daeriAccess
        self.storeAccess = storeAccess
        self.taxiPartnerId = taxiPartnerId
        self.daeriPartnerId = daeriPartnerId
        self.storePartnerId = storePartnerId
        self.userProfileURL = userProfileURL
        self.agreedNormalTerms = agreedNormalTerms
        self.agreedPartnerTerms = agreedPartnerTerms
    }
}

struct UserProfilePatch: Sendable {
    var displayName: String?
    var marketId: String?
    var userProfileURL: String?
    var mode: UserMode?
    var taxiAccess: ApprovalStatus?
    var daeriAccess: ApprovalStatus?
    var storeAccess: ApprovalStatus?
    var taxiPartnerId: String?
    var daeriPartnerId: String?
    var storePartnerId: String?
    var agreedNormalTerms: [String: Bool]?
    var agreedPartnerTerms: [String: Bool]?

    init(
        displayName: String? = nil,
        marketId: String? = nil,
        userProfileURL: String? = nil,
        mode: UserMode? = nil,
        taxiAccess: ApprovalStatus? = nil,
        daeriAccess: ApprovalStatus? = nil,
        storeAccess: ApprovalStatus? = nil,
        taxiPartnerId: String? = nil,
        daeriPartnerId: String? = nil,
        storePartnerId: String? = nil,
        agreedNormalTerms: [String: Bool]? = nil,
        agreedPartnerTerms: [String: Bool]? = nil
    ) {
        self.displayName = displayName
        self.marketId = marketId
        self.userProfileURL = userProfileURL
        self.mode = mode
        self.taxiAccess = taxiAccess
        self.daeriAccess = daeriAccess
        self.storeAccess = storeAccess
        self.taxiPartnerId = taxiPartnerId
        self.daeriPartnerId = daeriPartnerId
        self.storePartnerId = storePartnerId
        self.agreedNormalTerms = agreedNormalTerms
        self.agreedPartnerTerms = agreedPartnerTerms
    }
}

struct UserHistoryItem: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let service: ServiceType
    let status: MatchRequestStatus
    let marketId: String
    let createdAtMs: Int64
    let expireAtMs: Int64
    let providerId: String?
    let providerName: String?
    let providerProfileImageURL: String?
    let pickupLat: Double?
    let pickupLng: Double?

    init(
        requestId: String,
        service: ServiceType,
        status: MatchRequestStatus,
        marketId: String,
        createdAtMs: Int64,
        expireAtMs: Int64,
        providerId: String? = nil,
        providerName: String? = nil,
        providerProfileImageURL: String? = nil,
        pickupLat: Double? = nil,
        pickupLng: Double? = nil
    ) {
        self.id = requestId
        self.service = service
        self.status = status
        self.marketId = marketId
        self.createdAtMs = createdAtMs
        self.expireAtMs = expireAtMs
        self.providerId = providerId
        self.providerName = providerName
        self.providerProfileImageURL = providerProfileImageURL
        self.pickupLat = pickupLat
        self.pickupLng = pickupLng
    }
}

struct AuthUser: Codable, Equatable, Sendable {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?
}
