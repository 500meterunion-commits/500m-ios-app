import Combine
import FirebaseAuth
import Foundation

@MainActor
final class PartnerApplyViewModel: ObservableObject {
    struct DocumentDraft: Identifiable, Hashable {
        let id = UUID()
        let data: Data
        let ext: String
        let fileName: String
    }

    let mode: UserMode
    @Published var name = ""
    @Published var birthDate = ""
    @Published var contact = ""
    @Published var marketID = "busan"
    @Published var memo = ""
    @Published var carNumber = ""
    @Published var insuranceSubscribed = false
    @Published var storeCategory = "LIFE"
    @Published var selectedPlace: Place?
    @Published var documents: [DocumentDraft] = []
    @Published var agreePartnerTerms = false
    @Published private(set) var currentStatus: PartnerApplicationStatus?
    @Published private(set) var rejectReason: String?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published var didSubmit = false

    private var container: AppContainer?
    private var profileCancellable: AnyCancellable?

    init(mode: UserMode, container: AppContainer? = nil) {
        self.mode = mode
        self.container = container
        if container != nil {
            bindProfile()
            Task {
                await loadExistingApplication()
            }
        }
    }

    func configure(container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
        bindProfile()
        Task {
            await loadExistingApplication()
        }
    }

    var canSubmit: Bool {
        switch currentStatus {
        case .pending, .approved:
            return false
        case .rejected, .canceled, .none:
            return true
        }
    }

    func setDocumentItems(_ items: [DocumentDraft]) {
        documents = items
    }

    func submit() {
        Task {
            await performSubmit()
        }
    }

    private func bindProfile() {
        guard let container else { return }
        profileCancellable = container.observeCachedUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self, let profile else { return }
                if name.isEmpty { name = profile.displayName ?? "" }
                agreePartnerTerms = hasPartnerTerms(profile)
            }
    }

    private func loadExistingApplication() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let container else { return }

        do {
            let application = try await container.partnerApplicationRepository.getApplication(
                applicationId: "\(uid)_\(mode.rawValue)"
            )
            currentStatus = application?.status
            rejectReason = application?.rejectReason

            guard let payload = application?.payload else { return }
            name = payload["name"] ?? name
            birthDate = payload["birthDate"] ?? birthDate
            contact = payload["contact"] ?? contact
            marketID = payload["marketId"] ?? marketID
            memo = payload["memo"] ?? memo
            carNumber = payload["carNumber"] ?? carNumber
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performSubmit() async {
        guard canSubmit else {
            errorMessage = "현재 상태에서는 다시 제출할 수 없습니다."
            return
        }

        guard validate() else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "로그인이 필요합니다."
            return
        }
        guard let container else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if !agreePartnerTerms {
                _ = try await container.updateUserProfile(
                    uid: uid,
                    patch: UserProfilePatch(
                        agreedPartnerTerms: [
                            "terms_service": true,
                            "terms_location": true,
                        ]
                    )
                )
            }

            let uploadedURLs = try await uploadDocuments(uid: uid)
            try await container.submitPartnerApplication(
                mode: mode,
                marketId: marketID,
                payload: buildPayload(),
                attachments: uploadedURLs
            )
            currentStatus = .pending
            didSubmit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadDocuments(uid: String) async throws -> [String] {
        guard let container else { return [] }
        var urls: [String] = []
        for document in documents {
            let url = try await container.uploadPartnerDocument(uid: uid, data: document.data, ext: document.ext)
            urls.append(url)
        }
        return urls
    }

    private func validate() -> Bool {
        if documents.isEmpty {
            errorMessage = "인증서류를 최소 1개 이상 첨부해 주세요."
            return false
        }
        if name.nilIfBlank == nil {
            errorMessage = "이름을 입력해 주세요."
            return false
        }
        if birthDate.nilIfBlank == nil {
            errorMessage = "생년월일을 입력해 주세요."
            return false
        }
        if contact.nilIfBlank == nil {
            errorMessage = "연락처를 입력해 주세요."
            return false
        }

        switch mode {
        case .partnerTaxi:
            if carNumber.nilIfBlank == nil || memo.nilIfBlank == nil {
                errorMessage = "차량번호와 메모를 입력해 주세요."
                return false
            }
        case .partnerDaeri:
            if memo.nilIfBlank == nil {
                errorMessage = "메모를 입력해 주세요."
                return false
            }
        case .partnerStore:
            if selectedPlace == nil {
                errorMessage = "가게를 검색해서 선택해 주세요."
                return false
            }
        case .general:
            errorMessage = "잘못된 신청 모드입니다."
            return false
        }

        return true
    }

    private func buildPayload() -> [String: String] {
        var payload: [String: String] = [
            "name": name,
            "birthDate": birthDate,
            "contact": contact,
            "marketId": marketID,
        ]

        switch mode {
        case .partnerTaxi:
            payload["memo"] = memo
            payload["carNumber"] = carNumber
        case .partnerDaeri:
            payload["memo"] = memo
            payload["insuranceSubscribed"] = insuranceSubscribed ? "true" : "false"
        case .partnerStore:
            payload["storeName"] = selectedPlace?.name
            payload["storePlaceId"] = selectedPlace?.id
            payload["storeCategory"] = storeCategory
            if let lat = selectedPlace?.latitude {
                payload["storeLat"] = String(lat)
            }
            if let lng = selectedPlace?.longitude {
                payload["storeLng"] = String(lng)
            }
        case .general:
            break
        }
        return payload
    }

    private func hasPartnerTerms(_ profile: UserProfile) -> Bool {
        profile.agreedPartnerTerms?["terms_service"] == true &&
        profile.agreedPartnerTerms?["terms_location"] == true
    }
}
