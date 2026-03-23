import Combine
import FirebaseDatabase
import Foundation

final class DriverTrackingRepositoryLive: DriverTrackingRepository {
    private let database: DatabaseReference

    init(database: DatabaseReference = Database.database().reference()) {
        self.database = database
    }

    func observeDriverLocation(
        serviceType: ServiceType,
        driverId: String
    ) -> AnyPublisher<DriverLocation, Never> {
        database
            .child("driverLocations")
            .child(serviceType.rawValue)
            .child(driverId)
            .valuePublisher { snapshot in
                guard let value = snapshot.value as? [String: Any] else {
                    return nil
                }

                guard
                    let lat = value["lat"] as? Double,
                    let lng = value["lng"] as? Double,
                    let geohash = value["geohash"] as? String,
                    let status = value["status"] as? String,
                    let serviceTypeValue = value["serviceType"] as? String
                else {
                    return nil
                }

                return DriverLocation(
                    lat: lat,
                    lng: lng,
                    geohash: geohash,
                    updatedAt: (value["updatedAt"] as? NSNumber)?.int64Value ?? 0,
                    status: status,
                    serviceType: serviceTypeValue,
                    service: serviceType,
                    name: value["name"] as? String,
                    carNumber: value["carNumber"] as? String,
                    insuranceSubscribed: value["insuranceSubscribed"] as? Bool
                )
            }
            .eraseToAnyPublisher()
    }
}
