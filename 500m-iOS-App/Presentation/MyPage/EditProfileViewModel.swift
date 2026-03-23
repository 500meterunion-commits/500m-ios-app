import Combine
import Foundation

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var memo = ""
    @Published private(set) var mode: UserMode = .general
    @Published private(set) var remoteImageURL: String?
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private var container: AppContainer?
    private var profile: UserProfile?
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

    func save(imageData: Data?) {
        Task {
            await performSave(imageData: imageData)
        }
    }

    private func bindProfile() {
        guard let container else { return }
        container.observeCachedUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self, let profile else { return }
                self.profile = profile
                self.name = profile.displayName ?? ""
                self.mode = profile.mode
                self.remoteImageURL = profile.userProfileURL
            }
            .store(in: &cancellables)
    }

    private func performSave(imageData: Data?) async {
        guard let profile else { return }
        guard let container else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            var currentProfile = profile

            if currentProfile.displayName != name {
                currentProfile = try await container.updateUserProfile(
                    uid: currentProfile.id,
                    patch: UserProfilePatch(displayName: name)
                )
            }

            switch currentProfile.mode {
            case .general, .partnerStore:
                if let imageData, !imageData.isEmpty {
                    currentProfile = try await container.uploadUserProfileImage(uid: currentProfile.id, imageData: imageData)
                }
            case .partnerTaxi:
                try await saveTaxiPartner(profile: currentProfile, imageData: imageData)
            case .partnerDaeri:
                try await saveDaeriPartner(profile: currentProfile, imageData: imageData)
            }

            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveTaxiPartner(profile: UserProfile, imageData: Data?) async throws {
        guard let container else { return }
        guard let partnerID = profile.taxiPartnerId else { return }
        let current = try await container.partnerRepository.getTaxiDriver(driverId: partnerID)
        let uploadedURL: String?
        if let imageData, !imageData.isEmpty {
            uploadedURL = try await container.partnerRepository.uploadTaxiDriverPhoto(driverId: partnerID, imageData: imageData)
        } else {
            uploadedURL = nil
        }

        let next = TaxiDriver(
            driverId: partnerID,
            marketId: current?.marketId ?? profile.marketId,
            name: name,
            birthDate: current?.birthDate,
            phoneMasked: current?.phoneMasked,
            photoURL: uploadedURL ?? current?.photoURL,
            carNumber: current?.carNumber,
            memo: memo.nilIfBlank ?? current?.memo,
            insuranceShared: current?.insuranceShared
        )
        try await container.partnerRepository.upsertTaxiDriver(next)
    }

    private func saveDaeriPartner(profile: UserProfile, imageData: Data?) async throws {
        guard let container else { return }
        guard let partnerID = profile.daeriPartnerId else { return }
        let current = try await container.partnerRepository.getDaeriDriver(driverId: partnerID)
        let uploadedURL: String?
        if let imageData, !imageData.isEmpty {
            uploadedURL = try await container.partnerRepository.uploadDaeriDriverPhoto(driverId: partnerID, imageData: imageData)
        } else {
            uploadedURL = nil
        }

        let next = DaeriDriver(
            driverId: partnerID,
            marketId: current?.marketId ?? profile.marketId,
            name: name,
            birthDate: current?.birthDate,
            phoneMasked: current?.phoneMasked,
            photoURL: uploadedURL ?? current?.photoURL,
            insuranceSubscribed: current?.insuranceSubscribed,
            memo: memo.nilIfBlank ?? current?.memo,
            insuranceShared: current?.insuranceShared
        )
        try await container.partnerRepository.upsertDaeriDriver(next)
    }
}
