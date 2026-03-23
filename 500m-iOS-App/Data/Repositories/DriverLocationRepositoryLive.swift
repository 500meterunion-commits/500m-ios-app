import Combine
import FirebaseDatabase
import Foundation

final class DriverLocationRepositoryLive: DriverLocationRepository {
    private let database: DatabaseReference

    init(database: DatabaseReference = Database.database().reference()) {
        self.database = database
    }

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
    ) async throws {
        let serviceKey = serviceType.rawValue
        let oldGeohashSnapshot = try await RealtimeDatabaseAsync.getValue(
            database.child("driverLocations").child(serviceKey).child(driverId).child("geohash")
        )
        let oldGeohash = oldGeohashSnapshot.value as? String

        var updates: [String: Any?] = [
            "driverLocations/\(serviceKey)/\(driverId)/lat": lat,
            "driverLocations/\(serviceKey)/\(driverId)/lng": lng,
            "driverLocations/\(serviceKey)/\(driverId)/geohash": geohashPrefix,
            "driverLocations/\(serviceKey)/\(driverId)/updatedAt": ServerValue.timestamp(),
            "driverLocations/\(serviceKey)/\(driverId)/status": status,
            "driverLocations/\(serviceKey)/\(driverId)/serviceType": serviceKey,
            "driverLocations/\(serviceKey)/\(driverId)/name": name?.nilIfBlank,
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/lat": lat,
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/lng": lng,
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/updatedAt": ServerValue.timestamp(),
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/status": status,
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/serviceType": serviceKey,
            "geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/name": name?.nilIfBlank
        ]

        switch serviceType {
        case .taxi:
            updates["driverLocations/\(serviceKey)/\(driverId)/carNumber"] = carNumber
            updates["driverLocations/\(serviceKey)/\(driverId)/insuranceSubscribed"] = nil
            updates["geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/carNumber"] = carNumber
            updates["geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/insuranceSubscribed"] = nil
        case .daeri:
            updates["driverLocations/\(serviceKey)/\(driverId)/insuranceSubscribed"] = insuranceSubscribed
            updates["driverLocations/\(serviceKey)/\(driverId)/carNumber"] = nil
            updates["geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/insuranceSubscribed"] = insuranceSubscribed
            updates["geoIndex/\(serviceKey)/\(geohashPrefix)/\(driverId)/carNumber"] = nil
        case .store:
            break
        }

        if let oldGeohash, !oldGeohash.isEmpty, oldGeohash != geohashPrefix {
            updates["geoIndex/\(serviceKey)/\(oldGeohash)/\(driverId)"] = nil
        }

        try await RealtimeDatabaseAsync.updateChildren(database, values: updates)
    }

    func observeMarkersInCell(
        serviceType: ServiceType,
        geohashPrefix: String
    ) -> AnyPublisher<[DriverMarker], Never> {
        database
            .child("geoIndex")
            .child(serviceType.rawValue)
            .child(geohashPrefix)
            .valuePublisher { snapshot in
                Self.driverMarkers(from: snapshot)
            }
            .eraseToAnyPublisher()
    }

    func observeMarkersInCells(
        serviceType: ServiceType,
        cells: Set<String>
    ) -> AnyPublisher<[DriverMarker], Never> {
        let publishers = cells.sorted().map {
            observeMarkersInCell(serviceType: serviceType, geohashPrefix: $0)
        }
        guard !publishers.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }

        return CombineSupport.combineLatest(publishers)
            .map { arrays in
                let merged = arrays.flatMap { $0 }
                var latestByDriver = [String: DriverMarker]()
                for marker in merged.sorted(by: { $0.updatedAt > $1.updatedAt }) {
                    latestByDriver[marker.driverId] = marker
                }
                return Array(latestByDriver.values)
            }
            .eraseToAnyPublisher()
    }

    private static func driverMarkers(from snapshot: DataSnapshot) -> [DriverMarker] {
        snapshot.children.compactMap { child -> DriverMarker? in
            guard
                let child = child as? DataSnapshot,
                let value = child.value as? [String: Any],
                let lat = value["lat"] as? Double,
                let lng = value["lng"] as? Double,
                let status = value["status"] as? String,
                let serviceType = value["serviceType"] as? String
            else {
                return nil
            }

            return DriverMarker(
                driverId: child.key,
                lat: lat,
                lng: lng,
                status: status,
                serviceType: serviceType,
                updatedAt: (value["updatedAt"] as? NSNumber)?.int64Value ?? 0,
                name: value["name"] as? String,
                carNumber: value["carNumber"] as? String,
                insuranceSubscribed: value["insuranceSubscribed"] as? Bool
            )
        }
    }
}
