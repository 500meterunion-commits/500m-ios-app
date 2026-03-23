import Combine
import Foundation

protocol AuthRepository {
    func signInWithGoogle() async throws -> AuthUser
    func signInWithKakao() async throws -> AuthUser
    func signOut() async throws
    func requireUID() async throws -> String
    func deleteMyAccount() async throws
}

protocol UserRepository {
    func getUserProfile(uid: String) async throws -> UserProfile?
    func upsertUserProfile(_ profile: UserProfile) async throws
    func observeCachedProfile() -> AnyPublisher<UserProfile?, Never>
    func syncAndGetProfile(uid: String, displayName: String?, photoURL: String?) async throws -> UserProfile
    func uploadProfileImageAndUpdate(uid: String, imageData: Data) async throws -> UserProfile
    func updateProfile(uid: String, patch: UserProfilePatch) async throws -> UserProfile
    func clearLocal() async
}

protocol UserHistoryRepository {
    func observeHistory(uid: String, service: ServiceType?) -> AnyPublisher<[UserHistoryItem], Never>
    func upsertHistoryItem(uid: String, item: UserHistoryItem) async
}

protocol PartnerRepository {
    func getTaxiDriver(driverId: String) async throws -> TaxiDriver?
    func getDaeriDriver(driverId: String) async throws -> DaeriDriver?
    func getStore(storeId: String) async throws -> Store?
    func upsertTaxiDriver(_ driver: TaxiDriver) async throws
    func upsertDaeriDriver(_ driver: DaeriDriver) async throws
    func upsertStore(_ store: Store) async throws
    func uploadStorePromoImage(storeId: String, imageData: Data) async throws -> String
    func uploadTaxiDriverPhoto(driverId: String, imageData: Data) async throws -> String
    func uploadDaeriDriverPhoto(driverId: String, imageData: Data) async throws -> String
}

protocol PartnerApplicationRepository {
    func getApplication(applicationId: String) async throws -> PartnerApplication?
    func upsertApplication(_ application: PartnerApplication) async throws
    func uploadPartnerDocument(uid: String, data: Data, ext: String) async throws -> String
}

protocol MatchRepository {
    func requestMatch(
        marketId: String,
        serviceType: ServiceType,
        userId: String,
        driverId: String,
        pickupLat: Double,
        pickupLng: Double,
        memo: String?
    ) async throws -> String
    func observeMyPendingRequests(driverId: String, marketId: String, serviceType: ServiceType) -> AnyPublisher<[MatchRequest], Never>
    func acceptRequest(requestId: String) async throws
    func rejectRequest(requestId: String) async throws
    func startRide(requestId: String) async throws
    func completeRide(requestId: String) async throws
    func observeMatchRequest(requestId: String) -> AnyPublisher<MatchRequest?, Never>
    func cancelRequest(requestId: String) async throws
    func expireIfPending(requestId: String) async throws
}

protocol LocationRepository {
    func observeLocation() -> AnyPublisher<LatLng, Never>
}

protocol DirectionsRepository {
    func getRoute(originLat: Double, originLng: Double, destLat: Double, destLng: Double) async throws -> RoutePolyline
}

protocol PlaceRepository {
    func searchPlaces(
        query: String,
        page: Int,
        size: Int,
        centerLng: Double?,
        centerLat: Double?,
        radiusM: Int?
    ) async throws -> [Place]
}

protocol UserTokenRepository {
    func registerUserToken(uid: String, token: String) async throws
}

protocol DriverTokenRepository {
    func registerToken(
        driverId: String,
        token: String,
        marketId: String,
        serviceType: ServiceType
    ) async throws
    func unregisterToken(driverId: String) async throws
}

protocol DriverLocationRepository {
    func updateMyLocation(
        serviceType: ServiceType,
        driverId: String,
        lat: Double,
        lng: Double,
        geohashPrefix: String,
        status: String,
        name: String?,
        carNumber: String?,
        insuranceSubscribed: Bool?
    ) async throws
    func observeMarkersInCell(
        serviceType: ServiceType,
        geohashPrefix: String
    ) -> AnyPublisher<[DriverMarker], Never>
    func observeMarkersInCells(
        serviceType: ServiceType,
        cells: Set<String>
    ) -> AnyPublisher<[DriverMarker], Never>
}

protocol DriverTrackingRepository {
    func observeDriverLocation(
        serviceType: ServiceType,
        driverId: String
    ) -> AnyPublisher<DriverLocation, Never>
}

protocol DriverRealtimeRepository {
    func deleteDriverLocationAndIndex(serviceType: ServiceType, driverId: String) async throws
}

protocol StoreLocationRepository {
    func upsertStoreIndex(
        storeId: String,
        kakaoStoreRegId: String,
        category: String,
        lat: Double,
        lng: Double,
        geohashPrefix: String,
        storeName: String?,
        promoImageURL: String?,
        promoText: String?
    ) async throws
    func observeStoresInCell(geohashPrefix: String) -> AnyPublisher<[StoreMarker], Never>
    func observeStoresInCells(cells: Set<String>) -> AnyPublisher<[StoreMarker], Never>
}

protocol CellCalculator {
    func nearbyCells(lat: Double, lng: Double, radiusM: Double) -> Set<String>
}

protocol GeohashEncoder {
    func encodePrefix(lat: Double, lng: Double, length: Int) -> String
}
