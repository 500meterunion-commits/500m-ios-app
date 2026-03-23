import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let environment: AppEnvironment
    let authRepository: AuthRepository
    let userRepository: UserRepository
    let userHistoryRepository: UserHistoryRepository
    let partnerRepository: PartnerRepository
    let partnerApplicationRepository: PartnerApplicationRepository
    let matchRepository: MatchRepository
    let locationRepository: LocationRepository
    let directionsRepository: DirectionsRepository
    let placeRepository: PlaceRepository
    let userTokenRepository: UserTokenRepository
    let driverTokenRepository: DriverTokenRepository
    let driverLocationRepository: DriverLocationRepository
    let driverTrackingRepository: DriverTrackingRepository
    let driverRealtimeRepository: DriverRealtimeRepository
    let storeLocationRepository: StoreLocationRepository
    let geohashEncoder: GeohashEncoder
    let cellCalculator: CellCalculator

    let observeCachedUserProfile: ObserveCachedUserProfileUseCase
    let signInWithGoogle: SignInWithGoogleUseCase
    let signInWithKakao: SignInWithKakaoUseCase
    let signOut: SignOutUseCase
    let deleteMyAccount: DeleteMyAccountUseCase
    let syncAndGetUserProfile: SyncAndGetUserProfileUseCase
    let updateUserProfile: UpdateUserProfileUseCase
    let uploadUserProfileImage: UploadUserProfileImageUseCase
    let observeUserHistory: ObserveUserHistoryUseCase
    let observeUserLocation: ObserveUserLocationUseCase
    let getPartnerInfo: GetPartnerInfoUseCase
    let submitPartnerApplication: SubmitPartnerApplicationUseCase
    let uploadPartnerDocument: UploadPartnerDocumentUseCase
    let decidePartnerSwitch: DecidePartnerSwitchUseCase
    let requestMatch: RequestMatchUseCase
    let observeMatchRequest: ObserveMatchRequestUseCase
    let observeDriverPendingRequests: ObserveDriverPendingRequestsUseCase
    let acceptMatchRequest: AcceptMatchRequestUseCase
    let rejectMatchRequest: RejectMatchRequestUseCase
    let startRide: StartRideUseCase
    let completeRide: CompleteRideUseCase
    let cancelMatchRequest: CancelMatchRequestUseCase
    let expireIfPending: ExpireIfPendingUseCase
    let getRoutePolyline: GetRoutePolylineUseCase
    let searchPlaces: SearchPlacesUseCase
    let registerUserFcmToken: RegisterUserFcmTokenUseCase
    let registerDriverFcmToken: RegisterDriverFcmTokenUseCase
    let unregisterDriverFcmToken: UnregisterDriverFcmTokenUseCase
    let updateMyDriverLocation: UpdateMyDriverLocationUseCase
    let observeMarkersInCell: ObserveMarkersInCellUseCase
    let observeNearbyDrivers: ObserveNearbyDriversUseCase
    let observeDriverLocation: ObserveDriverLocationUseCase
    let deleteDriverRealtimeData: DeleteDriverRealtimeDataUseCase
    let upsertStoreIndex: UpsertStoreIndexUseCase
    let observeNearbyStores: ObserveNearbyStoresUseCase

    init() {
        let environment = AppEnvironment.shared
        let authRepository = AuthRepositoryLive(environment: environment)
        let userRepository = UserRepositoryLive()
        let userHistoryRepository = UserHistoryRepositoryLive()
        let partnerRepository = PartnerRepositoryLive()
        let partnerApplicationRepository = PartnerApplicationRepositoryLive()
        let locationRepository = LocationRepositoryLive()
        let directionsRepository = DirectionsRepositoryLive(environment: environment)
        let placeRepository = PlaceRepositoryLive(environment: environment)
        let userTokenRepository = UserTokenRepositoryLive()
        let driverTokenRepository = DriverTokenRepositoryLive()
        let driverLocationRepository = DriverLocationRepositoryLive()
        let driverTrackingRepository = DriverTrackingRepositoryLive()
        let driverRealtimeRepository = DriverRealtimeRepositoryLive()
        let storeLocationRepository = StoreLocationRepositoryLive()
        let geohashEncoder = GeohashEncoderLive()
        let cellCalculator = CellCalculatorLive(geohashEncoder: geohashEncoder)
        let matchRepository = MatchRepositoryLive(
            historyRepository: userHistoryRepository,
            partnerRepository: partnerRepository
        )

        self.environment = environment
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.userHistoryRepository = userHistoryRepository
        self.partnerRepository = partnerRepository
        self.partnerApplicationRepository = partnerApplicationRepository
        self.matchRepository = matchRepository
        self.locationRepository = locationRepository
        self.directionsRepository = directionsRepository
        self.placeRepository = placeRepository
        self.userTokenRepository = userTokenRepository
        self.driverTokenRepository = driverTokenRepository
        self.driverLocationRepository = driverLocationRepository
        self.driverTrackingRepository = driverTrackingRepository
        self.driverRealtimeRepository = driverRealtimeRepository
        self.storeLocationRepository = storeLocationRepository
        self.geohashEncoder = geohashEncoder
        self.cellCalculator = cellCalculator

        self.observeCachedUserProfile = ObserveCachedUserProfileUseCase(repository: userRepository)
        self.signInWithGoogle = SignInWithGoogleUseCase(repository: authRepository)
        self.signInWithKakao = SignInWithKakaoUseCase(repository: authRepository)
        self.signOut = SignOutUseCase(repository: authRepository)
        self.deleteMyAccount = DeleteMyAccountUseCase(repository: authRepository)
        self.syncAndGetUserProfile = SyncAndGetUserProfileUseCase(repository: userRepository)
        self.updateUserProfile = UpdateUserProfileUseCase(repository: userRepository)
        self.uploadUserProfileImage = UploadUserProfileImageUseCase(repository: userRepository)
        self.observeUserHistory = ObserveUserHistoryUseCase(repository: userHistoryRepository)
        self.observeUserLocation = ObserveUserLocationUseCase(repository: locationRepository)
        self.getPartnerInfo = GetPartnerInfoUseCase(repository: partnerRepository)
        self.submitPartnerApplication = SubmitPartnerApplicationUseCase(
            applicationRepository: partnerApplicationRepository,
            authRepository: authRepository
        )
        self.uploadPartnerDocument = UploadPartnerDocumentUseCase(repository: partnerApplicationRepository)
        self.decidePartnerSwitch = DecidePartnerSwitchUseCase(
            userRepository: userRepository,
            applicationRepository: partnerApplicationRepository
        )
        self.requestMatch = RequestMatchUseCase(repository: matchRepository)
        self.observeMatchRequest = ObserveMatchRequestUseCase(repository: matchRepository)
        self.observeDriverPendingRequests = ObserveDriverPendingRequestsUseCase(repository: matchRepository)
        self.acceptMatchRequest = AcceptMatchRequestUseCase(repository: matchRepository)
        self.rejectMatchRequest = RejectMatchRequestUseCase(repository: matchRepository)
        self.startRide = StartRideUseCase(repository: matchRepository)
        self.completeRide = CompleteRideUseCase(repository: matchRepository)
        self.cancelMatchRequest = CancelMatchRequestUseCase(repository: matchRepository)
        self.expireIfPending = ExpireIfPendingUseCase(repository: matchRepository)
        self.getRoutePolyline = GetRoutePolylineUseCase(repository: directionsRepository)
        self.searchPlaces = SearchPlacesUseCase(repository: placeRepository)
        self.registerUserFcmToken = RegisterUserFcmTokenUseCase(repository: userTokenRepository)
        self.registerDriverFcmToken = RegisterDriverFcmTokenUseCase(repository: driverTokenRepository)
        self.unregisterDriverFcmToken = UnregisterDriverFcmTokenUseCase(repository: driverTokenRepository)
        self.updateMyDriverLocation = UpdateMyDriverLocationUseCase(repository: driverLocationRepository)
        self.observeMarkersInCell = ObserveMarkersInCellUseCase(repository: driverLocationRepository)
        self.observeNearbyDrivers = ObserveNearbyDriversUseCase(
            cellCalculator: cellCalculator,
            repository: driverLocationRepository
        )
        self.observeDriverLocation = ObserveDriverLocationUseCase(repository: driverTrackingRepository)
        self.deleteDriverRealtimeData = DeleteDriverRealtimeDataUseCase(repository: driverRealtimeRepository)
        self.upsertStoreIndex = UpsertStoreIndexUseCase(
            repository: storeLocationRepository,
            geohashEncoder: geohashEncoder
        )
        self.observeNearbyStores = ObserveNearbyStoresUseCase(
            cellCalculator: cellCalculator,
            repository: storeLocationRepository
        )
    }
}
