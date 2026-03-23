import Foundation

struct DriverMarker: Codable, Equatable, Sendable, Identifiable {
    let driverId: String
    let lat: Double
    let lng: Double
    let status: String
    let serviceType: String
    let updatedAt: Int64
    let name: String?
    let carNumber: String?
    let insuranceSubscribed: Bool?

    var id: String { driverId }
}

struct DriverLocation: Codable, Equatable, Sendable {
    let lat: Double
    let lng: Double
    let geohash: String
    let updatedAt: Int64
    let status: String
    let serviceType: String
    let service: ServiceType
    let name: String?
    let carNumber: String?
    let insuranceSubscribed: Bool?
}

struct StoreMarker: Codable, Equatable, Sendable, Identifiable {
    let storeId: String
    let kakaoStoreRegId: String
    let category: String
    let lat: Double
    let lng: Double
    let storeName: String?
    let promoImageURL: String?
    let promoText: String?

    var id: String { storeId }
}
