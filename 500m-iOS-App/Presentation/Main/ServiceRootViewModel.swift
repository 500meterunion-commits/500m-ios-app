import Combine
import Foundation

@MainActor
final class ServiceRootViewModel: ObservableObject {
    @Published private(set) var userLocation: LatLng?
    @Published private(set) var stores: [StoreMarker] = []
    @Published private(set) var drivers: [DriverMarker] = []
    @Published private(set) var errorMessage: String?

    let tab: MainTab

    private var container: AppContainer?
    private var locationCancellable: AnyCancellable?
    private var nearbyCancellable: AnyCancellable?

    init(tab: MainTab, container: AppContainer? = nil) {
        self.tab = tab
        self.container = container
        if container != nil {
            observeLocation()
        }
    }

    func configure(container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
        observeLocation()
    }

    private func observeLocation() {
        guard let container else { return }
        locationCancellable = container.observeUserLocation()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }
                userLocation = location
                bindNearby(location: location)
            }
    }

    private func bindNearby(location: LatLng) {
        guard let container else { return }
        switch tab {
        case .store:
            nearbyCancellable = container.observeNearbyStores(
                userLat: location.lat,
                userLng: location.lng,
                radiusM: 500
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.stores = items.sorted { ($0.storeName ?? "") < ($1.storeName ?? "") }
                self?.drivers = []
            }
        case .taxi, .daeri:
            let service: ServiceType = tab == .taxi ? .taxi : .daeri
            nearbyCancellable = container.observeNearbyDrivers(
                serviceType: service,
                userLat: location.lat,
                userLng: location.lng,
                radiusM: 500
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.drivers = items.sorted { $0.updatedAt > $1.updatedAt }
                self?.stores = []
            }
        case .mypage:
            break
        }
    }
}
