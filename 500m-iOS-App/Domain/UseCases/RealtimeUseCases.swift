import Combine
import Foundation

struct RegisterUserFcmTokenUseCase {
    let repository: UserTokenRepository

    func callAsFunction(uid: String, token: String) async throws {
        try await repository.registerUserToken(uid: uid, token: token)
    }
}

struct RegisterDriverFcmTokenUseCase {
    let repository: DriverTokenRepository

    func callAsFunction(
        driverId: String,
        token: String,
        marketId: String,
        serviceType: ServiceType
    ) async throws {
        try await repository.registerToken(
            driverId: driverId,
            token: token,
            marketId: marketId,
            serviceType: serviceType
        )
    }
}

struct UnregisterDriverFcmTokenUseCase {
    let repository: DriverTokenRepository

    func callAsFunction(driverId: String) async throws {
        try await repository.unregisterToken(driverId: driverId)
    }
}

struct UpdateMyDriverLocationUseCase {
    let repository: DriverLocationRepository

    func callAsFunction(
        serviceType: ServiceType,
        driverId: String,
        lat: Double,
        lng: Double,
        geohashPrefix: String,
        status: String,
        name: String? = nil,
        carNumber: String? = nil,
        insuranceSubscribed: Bool? = nil
    ) async throws {
        try await repository.updateMyLocation(
            serviceType: serviceType,
            driverId: driverId,
            lat: lat,
            lng: lng,
            geohashPrefix: geohashPrefix,
            status: status,
            name: name,
            carNumber: carNumber,
            insuranceSubscribed: insuranceSubscribed
        )
    }
}

struct ObserveMarkersInCellUseCase {
    let repository: DriverLocationRepository

    func callAsFunction(
        serviceType: ServiceType,
        geohashPrefix: String
    ) -> AnyPublisher<[DriverMarker], Never> {
        repository.observeMarkersInCell(serviceType: serviceType, geohashPrefix: geohashPrefix)
    }
}

struct ObserveNearbyDriversUseCase {
    let cellCalculator: CellCalculator
    let repository: DriverLocationRepository

    func callAsFunction(
        serviceType: ServiceType,
        userLat: Double,
        userLng: Double,
        radiusM: Double
    ) -> AnyPublisher<[DriverMarker], Never> {
        let cells = cellCalculator.nearbyCells(lat: userLat, lng: userLng, radiusM: radiusM)
        guard !cells.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }

        return repository.observeMarkersInCells(serviceType: serviceType, cells: cells)
            .map { markers in
                markers.filter {
                    GeoMath.haversineMeters(userLat, userLng, $0.lat, $0.lng) <= radiusM
                }
            }
            .eraseToAnyPublisher()
    }
}

struct ObserveDriverLocationUseCase {
    let repository: DriverTrackingRepository

    func callAsFunction(
        serviceType: ServiceType,
        driverId: String
    ) -> AnyPublisher<DriverLocation, Never> {
        repository.observeDriverLocation(serviceType: serviceType, driverId: driverId)
    }
}

struct DeleteDriverRealtimeDataUseCase {
    let repository: DriverRealtimeRepository

    func callAsFunction(serviceType: ServiceType, driverId: String) async throws {
        try await repository.deleteDriverLocationAndIndex(serviceType: serviceType, driverId: driverId)
    }
}

struct UpsertStoreIndexUseCase {
    let repository: StoreLocationRepository
    let geohashEncoder: GeohashEncoder

    func callAsFunction(
        storeId: String,
        kakaoStoreRegId: String,
        category: String,
        lat: Double,
        lng: Double,
        storeName: String? = nil,
        promoImageURL: String? = nil,
        promoText: String? = nil
    ) async throws {
        let geohash = geohashEncoder.encodePrefix(lat: lat, lng: lng, length: 7)
        try await repository.upsertStoreIndex(
            storeId: storeId,
            kakaoStoreRegId: kakaoStoreRegId,
            category: category,
            lat: lat,
            lng: lng,
            geohashPrefix: geohash,
            storeName: storeName,
            promoImageURL: promoImageURL,
            promoText: promoText
        )
    }
}

struct ObserveNearbyStoresUseCase {
    let cellCalculator: CellCalculator
    let repository: StoreLocationRepository

    func callAsFunction(
        userLat: Double,
        userLng: Double,
        radiusM: Double = 500
    ) -> AnyPublisher<[StoreMarker], Never> {
        let cells = cellCalculator.nearbyCells(lat: userLat, lng: userLng, radiusM: radiusM)
        guard !cells.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }

        return repository.observeStoresInCells(cells: cells)
            .map { stores in
                stores.filter {
                    GeoMath.haversineMeters(userLat, userLng, $0.lat, $0.lng) <= radiusM
                }
            }
            .eraseToAnyPublisher()
    }
}
