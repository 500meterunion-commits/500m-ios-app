import Combine
import CoreLocation
import Foundation

final class LocationRepositoryLive: NSObject, LocationRepository, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let subject = PassthroughSubject<LatLng, Never>()
    private let minimumDistance: CLLocationDistance = 5
    private let minimumInterval: TimeInterval = 2
    private var lastPublishedLocation: CLLocation?
    private var lastPublishedAt: Date?
    private var pendingLocation: CLLocation?
    private var pendingWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minimumDistance
    }

    func observeLocation() -> AnyPublisher<LatLng, Never> {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        return subject.eraseToAnyPublisher()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        publishIfNeeded(location)
    }

    private func publishIfNeeded(_ location: CLLocation) {
        let now = Date()

        guard let lastPublishedLocation, let lastPublishedAt else {
            publish(location, at: now)
            return
        }

        let movedDistance = location.distance(from: lastPublishedLocation)
        guard movedDistance >= minimumDistance else { return }

        let elapsed = now.timeIntervalSince(lastPublishedAt)
        if elapsed >= minimumInterval {
            publish(location, at: now)
            return
        }

        pendingLocation = location
        pendingWorkItem?.cancel()

        let delay = minimumInterval - elapsed
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let pendingLocation else { return }
            let publishDate = Date()
            if let lastPublishedLocation = self.lastPublishedLocation,
               pendingLocation.distance(from: lastPublishedLocation) >= self.minimumDistance {
                self.publish(pendingLocation, at: publishDate)
            }
            self.pendingLocation = nil
            self.pendingWorkItem = nil
        }

        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func publish(_ location: CLLocation, at date: Date) {
        lastPublishedLocation = location
        lastPublishedAt = date
        subject.send(LatLng(lat: location.coordinate.latitude, lng: location.coordinate.longitude))
    }
}
