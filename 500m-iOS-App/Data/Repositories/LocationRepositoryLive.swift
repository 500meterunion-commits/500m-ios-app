import Combine
import CoreLocation
import Foundation

final class LocationRepositoryLive: NSObject, LocationRepository, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let subject = PassthroughSubject<LatLng, Never>()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func observeLocation() -> AnyPublisher<LatLng, Never> {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        return subject.eraseToAnyPublisher()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        subject.send(LatLng(lat: location.coordinate.latitude, lng: location.coordinate.longitude))
    }
}
