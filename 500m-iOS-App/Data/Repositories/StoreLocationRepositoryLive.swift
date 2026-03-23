import Combine
import FirebaseDatabase
import Foundation

final class StoreLocationRepositoryLive: StoreLocationRepository {
    private let database: DatabaseReference

    init(database: DatabaseReference = Database.database().reference()) {
        self.database = database
    }

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
    ) async throws {
        let oldGeohashSnapshot = try await RealtimeDatabaseAsync.getValue(
            database.child("storeLocations").child(storeId).child("geohash")
        )
        let oldGeohash = oldGeohashSnapshot.value as? String

        var updates: [String: Any?] = [
            "storeLocations/\(storeId)/lat": lat,
            "storeLocations/\(storeId)/lng": lng,
            "storeLocations/\(storeId)/geohash": geohashPrefix,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/kakaoStoreRegId": kakaoStoreRegId,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/category": category,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/lat": lat,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/lng": lng,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/storeName": storeName?.nilIfBlank,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/promoImageUrl": promoImageURL?.nilIfBlank,
            "geoIndex/STORE/\(geohashPrefix)/\(storeId)/promoText": promoText?.nilIfBlank
        ]

        if let oldGeohash, !oldGeohash.isEmpty, oldGeohash != geohashPrefix {
            updates["geoIndex/STORE/\(oldGeohash)/\(storeId)"] = nil
        }

        try await RealtimeDatabaseAsync.updateChildren(database, values: updates)
    }

    func observeStoresInCell(geohashPrefix: String) -> AnyPublisher<[StoreMarker], Never> {
        database
            .child("geoIndex")
            .child("STORE")
            .child(geohashPrefix)
            .valuePublisher { snapshot in
                Self.storeMarkers(from: snapshot)
            }
            .eraseToAnyPublisher()
    }

    func observeStoresInCells(cells: Set<String>) -> AnyPublisher<[StoreMarker], Never> {
        let publishers = cells.sorted().map(observeStoresInCell(geohashPrefix:))
        guard !publishers.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }

        return CombineSupport.combineLatest(publishers)
            .map { arrays in
                let merged = arrays.flatMap { $0 }
                var latestByStore = [String: StoreMarker]()
                for marker in merged {
                    latestByStore[marker.storeId] = marker
                }
                return Array(latestByStore.values)
            }
            .eraseToAnyPublisher()
    }

    private static func storeMarkers(from snapshot: DataSnapshot) -> [StoreMarker] {
        snapshot.children.compactMap { child -> StoreMarker? in
            guard
                let child = child as? DataSnapshot,
                let value = child.value as? [String: Any],
                let kakaoStoreRegId = value["kakaoStoreRegId"] as? String,
                let category = value["category"] as? String,
                let lat = value["lat"] as? Double,
                let lng = value["lng"] as? Double
            else {
                return nil
            }

            return StoreMarker(
                storeId: child.key,
                kakaoStoreRegId: kakaoStoreRegId,
                category: category,
                lat: lat,
                lng: lng,
                storeName: value["storeName"] as? String,
                promoImageURL: value["promoImageUrl"] as? String,
                promoText: value["promoText"] as? String
            )
        }
    }
}
