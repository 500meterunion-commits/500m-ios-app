import FirebaseDatabase
import Foundation

final class DriverRealtimeRepositoryLive: DriverRealtimeRepository {
    private let database: DatabaseReference

    init(database: DatabaseReference = Database.database().reference()) {
        self.database = database
    }

    func deleteDriverLocationAndIndex(serviceType: ServiceType, driverId: String) async throws {
        let serviceKey = serviceType.rawValue
        let geohashSnapshot = try await RealtimeDatabaseAsync.getValue(
            database.child("driverLocations").child(serviceKey).child(driverId).child("geohash")
        )
        let geohash = geohashSnapshot.value as? String

        var updates: [String: Any?] = [
            "driverLocations/\(serviceKey)/\(driverId)": nil
        ]
        if let geohash, !geohash.isEmpty {
            updates["geoIndex/\(serviceKey)/\(geohash)/\(driverId)"] = nil
        }

        try await RealtimeDatabaseAsync.updateChildren(database, values: updates)
    }
}
