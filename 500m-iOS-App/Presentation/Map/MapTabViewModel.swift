import Combine
import FirebaseAuth
import Foundation
import MapKit
import SwiftUI

@MainActor
final class MapTabViewModel: ObservableObject {
    enum Selection: Identifiable, Equatable {
        case driver(DriverMarker)
        case store(StoreMarker)

        var id: String {
            switch self {
            case let .driver(marker):
                return "driver_\(marker.id)"
            case let .store(marker):
                return "store_\(marker.id)"
            }
        }
    }

    let tab: MainTab

    @Published private(set) var profile: UserProfile?
    @Published private(set) var userLocation: LatLng?
    @Published private(set) var drivers: [DriverMarker] = []
    @Published private(set) var stores: [StoreMarker] = []
    @Published private(set) var selected: Selection?
    @Published private(set) var selectedPartnerInfo: PartnerInfo?
    @Published private(set) var activeMatch: MatchRequest?
    @Published private(set) var recentTerminalMatch: MatchRequest?
    @Published private(set) var trackedDriverLocation: DriverLocation?
    @Published private(set) var routePolyline: RoutePolyline?
    @Published private(set) var myDriverRequests: [MatchRequest] = []
    @Published private(set) var isAutoCalling = false
    @Published private(set) var autoCallCandidateIDs: [String] = []
    @Published private(set) var autoCallCurrentIndex = -1
    @Published private(set) var autoCallCurrentDriverID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var radiusMeters = 500
    @Published private(set) var isSubmitting = false
    @Published var alertMessage: String?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )

    private var container: AppContainer?
    private var cancellables = Set<AnyCancellable>()
    private var nearbyCancellable: AnyCancellable?
    private var activeMatchCancellable: AnyCancellable?
    private var driverRequestsCancellable: AnyCancellable?
    private var trackedDriverCancellable: AnyCancellable?
    private var routeTask: Task<Void, Never>?
    private var lastRouteOrigin: LatLng?
    private var autoCallTask: Task<Void, Never>?
    private var lastNearbyLocation: LatLng?

    init(tab: MainTab, container: AppContainer? = nil) {
        self.tab = tab
        self.container = container
        if container != nil {
            bind()
        }
    }

    func configure(container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
        bind()
    }

    func selectDriver(_ marker: DriverMarker) {
        selected = .driver(marker)
        recentTerminalMatch = nil
        startTracking(driverId: marker.driverId)
        refreshRouteIfNeeded(from: LatLng(lat: marker.lat, lng: marker.lng), force: true)
        Task {
            await loadPartnerInfo(for: marker)
        }
    }

    func selectStore(_ marker: StoreMarker) {
        selected = .store(marker)
        recentTerminalMatch = nil
        if activeMatch == nil {
            trackedDriverLocation = nil
            routePolyline = nil
            trackedDriverCancellable = nil
            lastRouteOrigin = nil
            updateCamera()
        }
        Task {
            await loadStoreInfo(partnerId: marker.storeId)
        }
    }

    func clearSelection() {
        selected = nil
        if activeMatch == nil {
            selectedPartnerInfo = nil
            trackedDriverLocation = nil
            routePolyline = nil
            trackedDriverCancellable = nil
            lastRouteOrigin = nil
            updateCamera()
        }
    }

    func requestSelectedDriver() {
        guard case let .driver(marker) = selected else { return }
        recentTerminalMatch = nil
        Task {
            await requestMatch(for: marker)
        }
    }

    func startAutoCall() {
        guard tab == .taxi || tab == .daeri else {
            alertMessage = "자동 호출은 택시/대리에서만 가능합니다."
            return
        }
        guard activeMatch == nil else {
            alertMessage = "이미 진행 중인 호출이 있습니다."
            return
        }
        guard !drivers.isEmpty else {
            alertMessage = "주변 기사님이 없습니다."
            return
        }
        guard let userLocation else { return }

        let sortedIDs = drivers
            .sorted {
                GeoMath.haversineMeters(userLocation.lat, userLocation.lng, $0.lat, $0.lng)
                    < GeoMath.haversineMeters(userLocation.lat, userLocation.lng, $1.lat, $1.lng)
            }
            .map(\.driverId)

        isAutoCalling = true
        recentTerminalMatch = nil
        autoCallCandidateIDs = Array(NSOrderedSet(array: sortedIDs)) as? [String] ?? sortedIDs
        autoCallCurrentIndex = -1
        autoCallCurrentDriverID = nil
        alertMessage = nil
        tryNextAutoCall()
    }

    func cancelAutoCall() {
        autoCallTask?.cancel()
        autoCallTask = nil

        let pendingRequestID = activeMatch?.id
        let isPending = activeMatch?.status == .pending

        resetAutoCallState()

        if let pendingRequestID, isPending, let container {
            Task {
                try? await container.cancelMatchRequest(requestId: pendingRequestID)
            }
        }
    }

    func cancelActiveMatch() {
        guard let requestID = activeMatch?.id, let container else { return }
        Task {
            do {
                try await container.cancelMatchRequest(requestId: requestID)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func acceptDriverRequest(_ requestID: String) {
        guard let container else { return }
        Task {
            do {
                try await container.acceptMatchRequest(requestId: requestID)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func rejectDriverRequest(_ requestID: String) {
        guard let container else { return }
        Task {
            do {
                try await container.rejectMatchRequest(requestId: requestID)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func startRide(_ requestID: String) {
        guard let container else { return }
        Task {
            do {
                try await container.startRide(requestId: requestID)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func completeRide(_ requestID: String) {
        guard let container else { return }
        Task {
            do {
                try await container.completeRide(requestId: requestID)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func dismissRecentTerminalMatch() {
        recentTerminalMatch = nil
    }

    func recenterOnUser() {
        guard let userLocation else { return }
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: userLocation.lat, longitude: userLocation.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        cameraPosition = .region(region)
    }

    var shouldShowDriverConsole: Bool {
        guard let profile else { return false }
        switch tab {
        case .taxi:
            return profile.mode == .partnerTaxi
        case .daeri:
            return profile.mode == .partnerDaeri
        case .store, .mypage:
            return false
        }
    }

    var autoCallStatusText: String {
        guard isAutoCalling else { return "자동 호출 대기" }
        let step = max(0, autoCallCurrentIndex + 1)
        let total = autoCallCandidateIDs.count
        if let autoCallCurrentDriverID,
           let driver = drivers.first(where: { $0.driverId == autoCallCurrentDriverID }) {
            return "\(step)/\(total) \(driver.name?.nilIfBlank ?? "기사") 호출 중"
        }
        return "\(step)/\(total) 자동 호출 진행 중"
    }

    func cycleRadius() {
        switch radiusMeters {
        case 500:
            radiusMeters = 300
        case 300:
            radiusMeters = 100
        default:
            radiusMeters = 500
        }
        refreshNearbyIfPossible()
    }

    var routeDistanceText: String {
        let distance = routePolyline?.distanceM
            ?? estimatedDriverDistanceMeters
        guard let distance else { return "거리 확인 중" }
        if distance >= 1000 {
            return String(format: "%.1fkm", Double(distance) / 1000.0)
        }
        return "\(distance)m"
    }

    var routeEtaText: String {
        let duration = routePolyline?.durationSec
        guard let duration else { return "ETA 확인 중" }
        if duration >= 3600 {
            return "\(duration / 3600)시간 \((duration % 3600) / 60)분"
        }
        let minutes = max(1, Int(round(Double(duration) / 60.0)))
        return "\(minutes)분"
    }

    var selectedDriverName: String {
        if let selectedPartnerInfo {
            switch selectedPartnerInfo {
            case let .taxi(driver):
                return driver.name?.nilIfBlank ?? "택시 기사"
            case let .daeri(driver):
                return driver.name?.nilIfBlank ?? "대리 기사"
            case let .store(store):
                return store.storeName?.nilIfBlank ?? "가게"
            }
        }

        if let driverName = trackedDriverLocation?.name?.nilIfBlank {
            return driverName
        }

        switch selected {
        case let .driver(marker):
            return marker.name?.nilIfBlank ?? "기사"
        case let .store(store):
            return store.storeName?.nilIfBlank ?? "가게"
        case .none:
            return "기사"
        }
    }

    private var estimatedDriverDistanceMeters: Int? {
        guard let userLocation else { return nil }
        if let trackedDriverLocation {
            return Int(
                GeoMath.haversineMeters(
                    userLocation.lat,
                    userLocation.lng,
                    trackedDriverLocation.lat,
                    trackedDriverLocation.lng
                )
            )
        }

        if case let .driver(marker) = selected {
            return Int(
                GeoMath.haversineMeters(
                    userLocation.lat,
                    userLocation.lng,
                    marker.lat,
                    marker.lng
                )
            )
        }

        return nil
    }

    private var currentServiceType: ServiceType? {
        switch tab {
        case .taxi:
            return .taxi
        case .daeri:
            return .daeri
        case .store, .mypage:
            return nil
        }
    }

    private func bind() {
        guard let container else { return }

        container.observeCachedUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                Task { @MainActor [weak self] in
                    self?.bindDriverRequestsIfNeeded()
                }
            }
            .store(in: &cancellables)

        container.observeUserLocation()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }
                userLocation = location
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )
                cameraPosition = .region(region)
                bindNearby(using: location)
                if let trackedDriverLocation {
                    refreshRouteIfNeeded(
                        from: LatLng(lat: trackedDriverLocation.lat, lng: trackedDriverLocation.lng),
                        force: false
                    )
                } else {
                    updateCamera()
                }
            }
            .store(in: &cancellables)
    }

    private func bindNearby(using location: LatLng) {
        guard let container else { return }

        switch tab {
        case .store:
            lastNearbyLocation = location
            isLoading = true
            nearbyCancellable = container.observeNearbyStores(
                userLat: location.lat,
                userLng: location.lng,
                radiusM: Double(radiusMeters)
            )
                .receive(on: DispatchQueue.main)
                .sink { [weak self] stores in
                    self?.isLoading = false
                    self?.stores = stores.sorted { ($0.storeName ?? "") < ($1.storeName ?? "") }
                    self?.drivers = []
                }
        case .taxi, .daeri:
            lastNearbyLocation = location
            isLoading = true
            let serviceType: ServiceType = tab == .taxi ? .taxi : .daeri
            nearbyCancellable = container.observeNearbyDrivers(
                serviceType: serviceType,
                userLat: location.lat,
                userLng: location.lng,
                radiusM: Double(radiusMeters)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] drivers in
                self?.isLoading = false
                self?.drivers = drivers.sorted { $0.updatedAt > $1.updatedAt }
                self?.stores = []
            }
        case .mypage:
            break
        }
    }

    private func refreshNearbyIfPossible() {
        guard let location = lastNearbyLocation ?? userLocation else { return }
        nearbyCancellable?.cancel()
        nearbyCancellable = nil
        bindNearby(using: location)
    }

    private func loadPartnerInfo(for marker: DriverMarker) async {
        guard let container else { return }
        let mode: UserMode = tab == .taxi ? .partnerTaxi : .partnerDaeri
        do {
            selectedPartnerInfo = try await container.getPartnerInfo(partnerId: marker.driverId, mode: mode)
        } catch {
            selectedPartnerInfo = nil
        }
    }

    private func requestMatch(for marker: DriverMarker) async {
        guard let container, let profile, let location = userLocation else { return }
        guard let marketID = profile.marketId?.nilIfBlank else {
            alertMessage = "사용자 marketId가 필요합니다."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let requestID = try await container.requestMatch(
                marketId: marketID,
                serviceType: tab == .taxi ? .taxi : .daeri,
                userId: profile.id,
                driverId: marker.driverId,
                pickupLat: location.lat,
                pickupLng: location.lng,
                memo: isAutoCalling ? "자동 호출" : nil
            )
            observeActiveMatch(requestID: requestID)
        } catch {
            alertMessage = error.localizedDescription
            if isAutoCalling {
                tryNextAutoCall()
            }
        }
    }

    private func observeActiveMatch(requestID: String) {
        guard let container else { return }
        activeMatchCancellable = container.observeMatchRequest(requestId: requestID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                guard let self else { return }
                activeMatch = request

                guard let request else {
                    if selected == nil {
                        selectedPartnerInfo = nil
                        trackedDriverLocation = nil
                        routePolyline = nil
                        trackedDriverCancellable = nil
                        lastRouteOrigin = nil
                    }
                    updateCamera()
                    return
                }

                startTracking(driverId: request.driverId)
                Task {
                    await self.loadPartnerInfo(partnerId: request.driverId)
                }

                if isTerminalStatus(request.status), selected == nil {
                    routePolyline = nil
                    trackedDriverLocation = nil
                    trackedDriverCancellable = nil
                    lastRouteOrigin = nil
                }

                switch request.status {
                case .pending:
                    break
                case .accepted, .inProgress:
                    recentTerminalMatch = nil
                    resetAutoCallState()
                case .completed:
                    recentTerminalMatch = request
                    resetAutoCallState()
                    clearRideStateAfterCompletion()
                case .rejected, .canceled, .expired:
                    if isAutoCalling {
                        tryNextAutoCall()
                    } else {
                        recentTerminalMatch = request
                        clearRideStateAfterCompletion()
                    }
                }

                updateCamera()
            }
    }

    private func bindDriverRequestsIfNeeded() {
        guard let container, let profile, shouldShowDriverConsole else {
            myDriverRequests = []
            driverRequestsCancellable = nil
            return
        }

        guard let marketID = profile.marketId?.nilIfBlank else { return }

        let serviceType: ServiceType
        let driverID: String?
        switch tab {
        case .taxi:
            serviceType = .taxi
            driverID = profile.taxiPartnerId
        case .daeri:
            serviceType = .daeri
            driverID = profile.daeriPartnerId
        case .store, .mypage:
            return
        }

        guard let driverID else { return }
        driverRequestsCancellable = container.observeDriverPendingRequests(
            driverId: driverID,
            marketId: marketID,
            serviceType: serviceType
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] requests in
            self?.myDriverRequests = requests.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func startTracking(driverId: String) {
        guard let container, let serviceType = currentServiceType else { return }
        trackedDriverCancellable = container.observeDriverLocation(serviceType: serviceType, driverId: driverId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }
                trackedDriverLocation = location
                refreshRouteIfNeeded(
                    from: LatLng(lat: location.lat, lng: location.lng),
                    force: false
                )
                updateCamera()
            }
    }

    private func refreshRouteIfNeeded(from origin: LatLng, force: Bool) {
        guard let container, userLocation != nil, currentServiceType != nil else { return }
        if !force, let lastRouteOrigin {
            let movedDistance = GeoMath.haversineMeters(
                origin.lat,
                origin.lng,
                lastRouteOrigin.lat,
                lastRouteOrigin.lng
            )
            if movedDistance < 25 {
                return
            }
        }

        lastRouteOrigin = origin
        routeTask?.cancel()
        routeTask = Task { [weak self] in
            guard let self, let userLocation else { return }
            do {
                let route = try await container.getRoutePolyline(
                    originLat: origin.lat,
                    originLng: origin.lng,
                    destLat: userLocation.lat,
                    destLng: userLocation.lng
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.routePolyline = route
                    self.updateCamera()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.routePolyline = nil
                    self.updateCamera()
                }
            }
        }
    }

    private func loadPartnerInfo(partnerId: String) async {
        guard let container, let mode = partnerMode else { return }
        do {
            selectedPartnerInfo = try await container.getPartnerInfo(partnerId: partnerId, mode: mode)
        } catch {
            selectedPartnerInfo = nil
        }
    }

    private func loadStoreInfo(partnerId: String) async {
        guard let container else { return }
        do {
            selectedPartnerInfo = try await container.getPartnerInfo(partnerId: partnerId, mode: .partnerStore)
        } catch {
            selectedPartnerInfo = nil
        }
    }

    private var partnerMode: UserMode? {
        switch tab {
        case .taxi:
            return .partnerTaxi
        case .daeri:
            return .partnerDaeri
        case .store, .mypage:
            return nil
        }
    }

    private func isTerminalStatus(_ status: MatchRequestStatus) -> Bool {
        switch status {
        case .completed, .rejected, .canceled, .expired:
            return true
        case .pending, .accepted, .inProgress:
            return false
        }
    }

    private func tryNextAutoCall() {
        autoCallTask?.cancel()
        autoCallTask = Task { [weak self] in
            guard let self else { return }
            guard isAutoCalling else { return }

            let nextIndex = autoCallCurrentIndex + 1
            guard nextIndex < autoCallCandidateIDs.count else {
                await MainActor.run {
                    self.resetAutoCallState()
                    self.alertMessage = "주변 기사 매칭에 실패했습니다."
                }
                return
            }

            let nextDriverID = autoCallCandidateIDs[nextIndex]
            guard let marker = drivers.first(where: { $0.driverId == nextDriverID }) else {
                await MainActor.run {
                    self.autoCallCurrentIndex = nextIndex
                    self.autoCallCurrentDriverID = nextDriverID
                }
                self.tryNextAutoCall()
                return
            }

            await MainActor.run {
                self.autoCallCurrentIndex = nextIndex
                self.autoCallCurrentDriverID = nextDriverID
                self.selected = .driver(marker)
                self.startTracking(driverId: marker.driverId)
                self.refreshRouteIfNeeded(from: LatLng(lat: marker.lat, lng: marker.lng), force: true)
            }
            await loadPartnerInfo(for: marker)
            await requestMatch(for: marker)
        }
    }

    private func resetAutoCallState() {
        isAutoCalling = false
        autoCallCandidateIDs = []
        autoCallCurrentIndex = -1
        autoCallCurrentDriverID = nil
        autoCallTask?.cancel()
        autoCallTask = nil
    }

    private func clearRideStateAfterCompletion() {
        activeMatch = nil
        trackedDriverLocation = nil
        trackedDriverCancellable = nil
        routePolyline = nil
        lastRouteOrigin = nil
        if selected == nil {
            selectedPartnerInfo = nil
        }
    }

    private func updateCamera() {
        if let routePolyline, routePolyline.points.count > 1 {
            let coordinates = routePolyline.points.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
            var rect = MKMapRect.null
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                rect = rect.isNull ? pointRect : rect.union(pointRect)
            }
            if !rect.isNull {
                let padded = rect.insetBy(dx: -rect.size.width * 0.25 - 400, dy: -rect.size.height * 0.25 - 400)
                cameraPosition = .rect(padded)
                return
            }
        }

        if let userLocation, let trackedDriverLocation {
            let center = CLLocationCoordinate2D(
                latitude: (userLocation.lat + trackedDriverLocation.lat) / 2,
                longitude: (userLocation.lng + trackedDriverLocation.lng) / 2
            )
            let latDelta = max(abs(userLocation.lat - trackedDriverLocation.lat) * 1.8, 0.01)
            let lngDelta = max(abs(userLocation.lng - trackedDriverLocation.lng) * 1.8, 0.01)
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
            )
            self.region = region
            cameraPosition = .region(region)
            return
        }

        if let userLocation {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: userLocation.lat, longitude: userLocation.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            self.region = region
            cameraPosition = .region(region)
        }
    }
}
