import Combine
import FirebaseAuth
import Foundation
import UIKit

@MainActor
final class MyPageViewModel: ObservableObject {
    struct StorePromoState: Equatable {
        var storeId: String?
        var remoteImageURL: String?
        var localImageData: Data?
        var promoText: String = ""
        var isSaving = false
    }

    @Published private(set) var profile: UserProfile?
    @Published private(set) var partnerInfo: PartnerInfo?
    @Published private(set) var displayProfileImageURL: String?
    @Published private(set) var storePromo = StorePromoState()
    @Published private(set) var isBusy = false
    @Published var alertMessage: String?
    @Published var requestedRoute: MainRoute?

    private var container: AppContainer?
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer? = nil) {
        self.container = container
        if container != nil {
            bindProfile()
        }
    }

    func configure(container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
        bindProfile()
    }

    func displayNameText() -> String {
        profile?.displayName?.nilIfBlank ?? "이름 없음"
    }

    func gradeText() -> String {
        switch profile?.mode ?? .general {
        case .general: return "일반 사용자"
        case .partnerTaxi: return "택시 기사"
        case .partnerDaeri: return "대리 기사"
        case .partnerStore: return "자영업 파트너"
        }
    }

    func requestEditProfile() {
        requestedRoute = .editProfile
    }

    func requestUsageHistory() {
        requestedRoute = .usageHistory
    }

    func clearRequestedRoute() {
        requestedRoute = nil
    }

    func onPromoTextChange(_ value: String) {
        storePromo.promoText = value
    }

    func onPickPromoImage(_ data: Data?) {
        storePromo.localImageData = data
    }

    func saveStorePromo() {
        Task {
            await persistStorePromo()
        }
    }

    func onServiceToggle(_ mode: UserMode) {
        Task {
            await handleServiceToggle(mode)
        }
    }

    func logout() {
        Task {
            guard let container else { return }
            isBusy = true
            defer { isBusy = false }

            do {
                try await container.signOut()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func withdraw() {
        Task {
            guard let container else { return }
            isBusy = true
            defer { isBusy = false }

            do {
                try await container.deleteMyAccount()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func bindProfile() {
        guard let container else { return }
        container.observeCachedUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                Task { @MainActor [weak self] in
                    await self?.loadDisplayProfilePhoto()
                    await self?.loadPartnerInfo()
                    await self?.loadStorePromo()
                }
            }
            .store(in: &cancellables)
    }

    private func loadDisplayProfilePhoto() async {
        guard let profile else {
            displayProfileImageURL = nil
            return
        }
        guard let container else { return }

        do {
            switch profile.mode {
            case .partnerTaxi:
                guard let partnerID = profile.taxiPartnerId,
                      let driver = try await container.partnerRepository.getTaxiDriver(driverId: partnerID) else {
                    displayProfileImageURL = profile.userProfileURL
                    return
                }
                displayProfileImageURL = driver.photoURL?.nilIfBlank ?? profile.userProfileURL
            case .partnerDaeri:
                guard let partnerID = profile.daeriPartnerId,
                      let driver = try await container.partnerRepository.getDaeriDriver(driverId: partnerID) else {
                    displayProfileImageURL = profile.userProfileURL
                    return
                }
                displayProfileImageURL = driver.photoURL?.nilIfBlank ?? profile.userProfileURL
            case .general, .partnerStore:
                displayProfileImageURL = profile.userProfileURL
            }
        } catch {
            displayProfileImageURL = profile.userProfileURL
        }
    }

    private func loadPartnerInfo() async {
        guard let profile else {
            partnerInfo = nil
            return
        }
        guard let container else { return }

        do {
            switch profile.mode {
            case .partnerTaxi:
                guard let partnerID = profile.taxiPartnerId else { return }
                partnerInfo = try await container.getPartnerInfo(partnerId: partnerID, mode: .partnerTaxi)
            case .partnerDaeri:
                guard let partnerID = profile.daeriPartnerId else { return }
                partnerInfo = try await container.getPartnerInfo(partnerId: partnerID, mode: .partnerDaeri)
            case .partnerStore:
                guard let partnerID = profile.storePartnerId else { return }
                partnerInfo = try await container.getPartnerInfo(partnerId: partnerID, mode: .partnerStore)
            case .general:
                partnerInfo = nil
            }
        } catch {
            partnerInfo = nil
        }
    }

    private func loadStorePromo() async {
        guard let profile, profile.mode == .partnerStore else {
            storePromo = StorePromoState()
            return
        }
        guard let container, let storeID = profile.storePartnerId else { return }

        do {
            guard let store = try await container.partnerRepository.getStore(storeId: storeID) else {
                storePromo = StorePromoState(storeId: storeID)
                return
            }
            storePromo = StorePromoState(
                storeId: storeID,
                remoteImageURL: store.promoImageURL,
                localImageData: nil,
                promoText: store.promoText ?? "",
                isSaving: false
            )
        } catch {
            storePromo = StorePromoState(storeId: storeID)
        }
    }

    private func handleServiceToggle(_ mode: UserMode) async {
        guard let profile else { return }
        guard let container else { return }

        do {
            let uid = try await container.authRepository.requireUID()

            if profile.mode == mode {
                try await updateMode(.general)
                return
            }

            switch try await container.decidePartnerSwitch(uid: uid, mode: mode) {
            case let .openApply(target):
                requestedRoute = .partnerApply(target)
            case .showPending:
                alertMessage = "현재 심사 진행 중입니다. 승인 완료 후 전환할 수 있어요."
            case let .showRejected(_, reason):
                alertMessage = reason?.nilIfBlank ?? "이전 파트너 신청이 반려되었습니다."
                requestedRoute = .partnerApply(mode)
            case let .switchToPartner(target):
                try await updateMode(target)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func updateMode(_ mode: UserMode) async throws {
        guard let profile else { return }
        guard let container else { return }
        isBusy = true
        defer { isBusy = false }

        if mode == .general {
            switch profile.mode {
            case .partnerTaxi:
                if let partnerID = profile.taxiPartnerId {
                    try? await container.deleteDriverRealtimeData(serviceType: .taxi, driverId: partnerID)
                }
            case .partnerDaeri:
                if let partnerID = profile.daeriPartnerId {
                    try? await container.deleteDriverRealtimeData(serviceType: .daeri, driverId: partnerID)
                }
            case .partnerStore, .general:
                break
            }
        }

        _ = try await container.updateUserProfile(
            uid: profile.id,
            patch: UserProfilePatch(mode: mode)
        )
    }

    private func persistStorePromo() async {
        guard let container, let profile else { return }
        guard profile.mode == .partnerStore else { return }
        guard let storeID = profile.storePartnerId?.nilIfBlank else { return }

        let hasImage = storePromo.localImageData != nil || storePromo.remoteImageURL?.nilIfBlank != nil
        let hasText = storePromo.promoText.nilIfBlank != nil

        guard hasImage else {
            alertMessage = "홍보 이미지를 등록해 주세요."
            return
        }

        guard hasText else {
            alertMessage = "홍보 문구를 입력해 주세요."
            return
        }

        isBusy = true
        storePromo.isSaving = true
        defer {
            isBusy = false
            storePromo.isSaving = false
        }

        do {
            let currentStore = try await container.partnerRepository.getStore(storeId: storeID)
            let uploadedURL: String?
            if let imageData = storePromo.localImageData,
               !imageData.isEmpty {
                uploadedURL = try await container.partnerRepository.uploadStorePromoImage(
                    storeId: storeID,
                    imageData: imageData
                )
            } else {
                uploadedURL = nil
            }

            let nextStore = Store(
                storeId: storeID,
                marketId: currentStore?.marketId ?? profile.marketId,
                storeName: currentStore?.storeName,
                kakaoStoreRegId: currentStore?.kakaoStoreRegId,
                ownerBirthDate: currentStore?.ownerBirthDate,
                ownerName: currentStore?.ownerName,
                ownerPhone: currentStore?.ownerPhone,
                promoImageURL: uploadedURL ?? currentStore?.promoImageURL,
                promoText: storePromo.promoText.nilIfBlank ?? currentStore?.promoText,
                insuranceShared: currentStore?.insuranceShared,
                category: currentStore?.category,
                lat: currentStore?.lat,
                lng: currentStore?.lng
            )

            try await container.partnerRepository.upsertStore(nextStore)

            if let kakaoStoreRegId = nextStore.kakaoStoreRegId?.nilIfBlank,
               let category = nextStore.category?.nilIfBlank,
               let lat = nextStore.lat,
               let lng = nextStore.lng {
                try await container.upsertStoreIndex(
                    storeId: nextStore.id,
                    kakaoStoreRegId: kakaoStoreRegId,
                    category: category,
                    lat: lat,
                    lng: lng,
                    storeName: nextStore.storeName,
                    promoImageURL: nextStore.promoImageURL,
                    promoText: nextStore.promoText
                )
            }

            storePromo.remoteImageURL = nextStore.promoImageURL
            storePromo.localImageData = nil
            storePromo.promoText = nextStore.promoText ?? storePromo.promoText
            alertMessage = "홍보 내용이 저장되었습니다."
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
