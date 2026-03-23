import Foundation

struct TaxiDriver: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let marketId: String?
    let name: String?
    let birthDate: String?
    let phoneMasked: String?
    let photoURL: String?
    let carNumber: String?
    let memo: String?
    let insuranceShared: Bool?

    init(
        driverId: String,
        marketId: String? = nil,
        name: String? = nil,
        birthDate: String? = nil,
        phoneMasked: String? = nil,
        photoURL: String? = nil,
        carNumber: String? = nil,
        memo: String? = nil,
        insuranceShared: Bool? = false
    ) {
        self.id = driverId
        self.marketId = marketId
        self.name = name
        self.birthDate = birthDate
        self.phoneMasked = phoneMasked
        self.photoURL = photoURL
        self.carNumber = carNumber
        self.memo = memo
        self.insuranceShared = insuranceShared
    }
}

struct DaeriDriver: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let marketId: String?
    let name: String?
    let birthDate: String?
    let phoneMasked: String?
    let photoURL: String?
    let insuranceSubscribed: Bool?
    let memo: String?
    let insuranceShared: Bool?

    init(
        driverId: String,
        marketId: String? = nil,
        name: String? = nil,
        birthDate: String? = nil,
        phoneMasked: String? = nil,
        photoURL: String? = nil,
        insuranceSubscribed: Bool? = nil,
        memo: String? = nil,
        insuranceShared: Bool? = false
    ) {
        self.id = driverId
        self.marketId = marketId
        self.name = name
        self.birthDate = birthDate
        self.phoneMasked = phoneMasked
        self.photoURL = photoURL
        self.insuranceSubscribed = insuranceSubscribed
        self.memo = memo
        self.insuranceShared = insuranceShared
    }
}

struct Store: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let marketId: String?
    let storeName: String?
    let kakaoStoreRegId: String?
    let ownerBirthDate: String?
    let ownerName: String?
    let ownerPhone: String?
    let promoImageURL: String?
    let promoText: String?
    let insuranceShared: Bool?
    let category: String?
    let lat: Double?
    let lng: Double?

    init(
        storeId: String,
        marketId: String? = nil,
        storeName: String? = nil,
        kakaoStoreRegId: String? = nil,
        ownerBirthDate: String? = nil,
        ownerName: String? = nil,
        ownerPhone: String? = nil,
        promoImageURL: String? = nil,
        promoText: String? = nil,
        insuranceShared: Bool? = false,
        category: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil
    ) {
        self.id = storeId
        self.marketId = marketId
        self.storeName = storeName
        self.kakaoStoreRegId = kakaoStoreRegId
        self.ownerBirthDate = ownerBirthDate
        self.ownerName = ownerName
        self.ownerPhone = ownerPhone
        self.promoImageURL = promoImageURL
        self.promoText = promoText
        self.insuranceShared = insuranceShared
        self.category = category
        self.lat = lat
        self.lng = lng
    }
}

enum PartnerInfo: Sendable, Equatable {
    case taxi(TaxiDriver)
    case daeri(DaeriDriver)
    case store(Store)
}

struct PartnerApplication: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let uid: String
    let mode: UserMode
    let marketId: String
    let status: PartnerApplicationStatus
    let partnerId: String?
    let payload: [String: String]
    let attachments: [String]
    let createdAt: Int64
    let updatedAt: Int64
    let reviewedAt: Int64
    let reviewedBy: String?
    let rejectReason: String?

    init(
        applicationId: String,
        uid: String,
        mode: UserMode,
        marketId: String,
        status: PartnerApplicationStatus,
        partnerId: String? = nil,
        payload: [String: String],
        attachments: [String],
        createdAt: Int64,
        updatedAt: Int64,
        reviewedAt: Int64 = 0,
        reviewedBy: String? = nil,
        rejectReason: String? = nil
    ) {
        self.id = applicationId
        self.uid = uid
        self.mode = mode
        self.marketId = marketId
        self.status = status
        self.partnerId = partnerId
        self.payload = payload
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.rejectReason = rejectReason
    }
}
