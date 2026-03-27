import SwiftUI
import UIKit

struct MyPageView: View {
    let profile: UserProfile
    let onRoute: (MainRoute) -> Void

    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = MyPageViewModel()
    @State private var confirmLogout = false
    @State private var confirmWithdraw = false
    @State private var showPromoImageSourceDialog = false
    @State private var activePromoMediaPicker: MediaPickerSource?
    @State private var showCameraUnavailableAlert = false

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let darkCard = Color(red: 0.18, green: 0.2, blue: 0.24)
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(profile: UserProfile, onRoute: @escaping (MainRoute) -> Void) {
        self.profile = profile
        self.onRoute = onRoute
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                titleSection
                accountCard
                serviceSection
                if currentProfile.mode == .partnerStore {
                    storePromoSection
                }
                infoSection
                actionSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 140)
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !isPreview else { return }
            viewModel.configure(container: container)
        }
        .onReceive(viewModel.$requestedRoute.compactMap { $0 }) { route in
            onRoute(route)
            viewModel.clearRequestedRoute()
        }
        .alert("안내", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { newValue in
                if !newValue { viewModel.alertMessage = nil }
            }
        )) {
            Button("확인") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .confirmationDialog("로그아웃 하시겠습니까?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) { viewModel.logout() }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("회원 탈퇴를 진행할까요?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
            Button("회원 탈퇴", role: .destructive) { viewModel.withdraw() }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("홍보 이미지를 선택해 주세요", isPresented: $showPromoImageSourceDialog, titleVisibility: .visible) {
            Button("앨범에서 선택") {
                activePromoMediaPicker = .photoLibrary(selectionLimit: 1)
            }
            Button("직접 촬영") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    activePromoMediaPicker = .camera
                } else {
                    showCameraUnavailableAlert = true
                }
            }
            Button("취소", role: .cancel) {}
        }
        .fullScreenCover(item: $activePromoMediaPicker) { source in
            ZStack {
                Color.black.ignoresSafeArea()
                MediaPicker(source: source) { images in
                    guard let image = images.first else { return }
                    viewModel.onPickPromoImage(image.jpegData(compressionQuality: 0.9))
                }
            }
            .ignoresSafeArea()
        }
        .alert("카메라를 사용할 수 없습니다", isPresented: $showCameraUnavailableAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("현재 기기에서는 카메라 촬영을 사용할 수 없어 앨범 선택만 가능합니다.")
        }
        .overlay {
            if viewModel.isBusy {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                ProgressView("잠시만 기다려 주세요...")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var currentProfile: UserProfile {
        viewModel.profile ?? profile
    }

    private var displayNameText: String {
        currentProfile.displayName?.nilIfBlank ?? "이름 없음"
    }

    private var titleSection: some View {
        Text("내 계정")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
            .padding(.top, 6)
    }

    private var accountCard: some View {
        Button {
            viewModel.requestEditProfile()
        } label: {
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    profileAvatar(size: 66)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayNameText)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

                        Text(gradeText(for: currentProfile.mode))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.8, green: 0.84, blue: 0.89))
                }

                if let summary = accountSummary {
                    VStack(alignment: .leading, spacing: 10) {
                        if let badge = accountBadgeText {
                            Text(badge)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(brandRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(brandRed.opacity(0.1), in: Capsule())
                        }

                        Text(summary)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.49))
                            .multilineTextAlignment(.leading)

                        if !accountMetaItems.isEmpty {
                            HStack(spacing: 10) {
                                ForEach(accountMetaItems, id: \.title) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
                                        Text(item.value)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.97, green: 0.98, blue: 0.99), in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("서비스 제공")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            VStack(spacing: 0) {
                if shouldShowMode(.partnerTaxi) {
                    serviceToggleRow(
                        title: currentProfile.mode == .partnerTaxi ? "일반 사용자 모드로 전환" : "택시 기사로 전환",
                        subtitle: modeStatusText(for: .partnerTaxi),
                        isOn: currentProfile.mode == .partnerTaxi
                    ) {
                        viewModel.onServiceToggle(.partnerTaxi)
                    }
                }

                if shouldShowMode(.partnerDaeri) {
                    if shouldShowMode(.partnerTaxi) {
                        divider(color: Color.white.opacity(0.08))
                    }
                    serviceToggleRow(
                        title: currentProfile.mode == .partnerDaeri ? "일반 사용자 모드로 전환" : "대리 기사로 전환",
                        subtitle: modeStatusText(for: .partnerDaeri),
                        isOn: currentProfile.mode == .partnerDaeri
                    ) {
                        viewModel.onServiceToggle(.partnerDaeri)
                    }
                }

                if shouldShowMode(.partnerStore) {
                    if shouldShowMode(.partnerTaxi) || shouldShowMode(.partnerDaeri) {
                        divider(color: Color.white.opacity(0.08))
                    }
                    serviceToggleRow(
                        title: currentProfile.mode == .partnerStore ? "일반 사용자 모드로 전환" : "자영업으로 전환",
                        subtitle: modeStatusText(for: .partnerStore),
                        isOn: currentProfile.mode == .partnerStore
                    ) {
                        viewModel.onServiceToggle(.partnerStore)
                    }
                }
            }
            .background(darkCard, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        }
    }

    private var storePromoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("매장 홍보 관리")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            VStack(alignment: .leading, spacing: 18) {
                Button {
                    showPromoImageSourceDialog = true
                } label: {
                    VStack(spacing: 14) {
                        promoPreview

                        Text(viewModel.storePromo.localImageData == nil && viewModel.storePromo.remoteImageURL?.nilIfBlank == nil ? "홍보 이미지를 등록해 주세요" : "이미지를 다시 선택하려면 탭하세요")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(Color(red: 0.99, green: 0.99, blue: 1.0), in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.95), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("홍보 문구")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.31, blue: 0.39))

                    TextField("매장 홍보 문구를 입력해 주세요", text: Binding(
                        get: { viewModel.storePromo.promoText },
                        set: { viewModel.onPromoTextChange($0) }
                    ), axis: .vertical)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                    .lineLimit(4, reservesSpace: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.95), lineWidth: 1.5)
                    }
                }

                Button {
                    viewModel.saveStorePromo()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(brandRed)
                        if viewModel.storePromo.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("홍보 내용 저장")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 56)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("정보")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            VStack(spacing: 0) {
                infoRow(icon: "clock.arrow.circlepath", title: "이용 내역", tint: brandRed) {
                    onRoute(.usageHistory)
                }
                divider(color: Color(red: 0.95, green: 0.96, blue: 0.98))
                infoRow(
                    icon: "info.circle",
                    title: "앱 정보",
                    tint: brandRed,
                    trailing: Text(appVersionText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
                        .eraseToAnyView()
                )
                divider(color: Color(red: 0.95, green: 0.96, blue: 0.98))
                infoRow(icon: "doc.text", title: "이용약관", tint: brandRed) {
                    onRoute(.terms)
                }
                divider(color: Color(red: 0.95, green: 0.96, blue: 0.98))
                infoRow(icon: "shield", title: "개인정보처리방침", tint: brandRed) {
                    onRoute(.privacy)
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                confirmLogout = true
            } label: {
                Text("로그아웃")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(brandRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(brandRed, lineWidth: 2)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    )
            }
            .buttonStyle(.plain)

            Button {
                confirmWithdraw = true
            } label: {
                Text("회원 탈퇴")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.77, blue: 0.82))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.87, green: 0.9, blue: 0.94), lineWidth: 1.5)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func shouldShowMode(_ mode: UserMode) -> Bool {
        switch mode {
        case .general:
            return false
        case .partnerTaxi, .partnerDaeri, .partnerStore:
            return true
        }
    }

    private func gradeText(for mode: UserMode) -> String {
        switch mode {
        case .general: return "일반 사용자"
        case .partnerTaxi: return "택시 기사"
        case .partnerDaeri: return "대리 기사"
        case .partnerStore: return "자영업 파트너"
        }
    }

    private func serviceToggleRow(title: String, subtitle: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                if let subtitle = subtitle?.nilIfBlank {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                }
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        guard newValue != isOn else { return }
                        action()
                    }
                )
            )
            .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        if let urlString = viewModel.displayProfileImageURL?.nilIfBlank ?? currentProfile.userProfileURL?.nilIfBlank,
           let url = URL(string: urlString) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                fallbackAvatar(size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar(size: size)
        }
    }

    private func fallbackAvatar(size: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.51, green: 0.35, blue: 0.78))
            .frame(width: size, height: size)
            .overlay {
                Text(initialLetter)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.white)
            }
    }

    private var initialLetter: String {
        let raw = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "A" : String(raw.prefix(1)).uppercased()
    }

    private func infoRow(
        icon: String,
        title: String,
        tint: Color,
        trailing: AnyView? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 34)

                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

                Spacer()

                if let trailing {
                    trailing
                } else if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.8, green: 0.84, blue: 0.89))
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 84)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func divider(color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(version)"
    }

    private func modeStatusText(for mode: UserMode) -> String? {
        switch mode {
        case .partnerTaxi:
            return approvalStatusText(currentProfile.taxiAccess)
        case .partnerDaeri:
            return approvalStatusText(currentProfile.daeriAccess)
        case .partnerStore:
            return approvalStatusText(currentProfile.storeAccess)
        case .general:
            return nil
        }
    }

    private var accountSummary: String? {
        switch currentProfile.mode {
        case .general:
            return "파트너 전환 후 택시, 대리, 자영업 서비스를 바로 관리할 수 있어요."
        case .partnerTaxi:
            guard case let .taxi(driver)? = viewModel.partnerInfo else {
                return "택시 기사 정보가 준비되면 여기에서 확인할 수 있어요."
            }
            return driver.memo?.nilIfBlank ?? "현재 택시 기사 모드로 활동 중입니다."
        case .partnerDaeri:
            guard case let .daeri(driver)? = viewModel.partnerInfo else {
                return "대리 기사 정보가 준비되면 여기에서 확인할 수 있어요."
            }
            return driver.memo?.nilIfBlank ?? "현재 대리 기사 모드로 활동 중입니다."
        case .partnerStore:
            guard case let .store(store)? = viewModel.partnerInfo else {
                return "매장 홍보와 파트너 정보를 여기에서 관리할 수 있어요."
            }
            return store.promoText?.nilIfBlank ?? "매장 홍보 문구를 등록해 근처 사용자에게 매장을 노출해 보세요."
        }
    }

    private var accountBadgeText: String? {
        switch currentProfile.mode {
        case .general:
            return nil
        case .partnerTaxi:
            return "택시 기사 모드"
        case .partnerDaeri:
            return "대리 기사 모드"
        case .partnerStore:
            return "자영업 파트너"
        }
    }

    private var accountMetaItems: [(title: String, value: String)] {
        switch viewModel.partnerInfo {
        case let .taxi(driver):
            return [
                ("자동차 번호", driver.carNumber?.nilIfBlank ?? "-"),
                ("연락 상태", approvalStatusText(currentProfile.taxiAccess) ?? "-")
            ]
        case let .daeri(driver):
            return [
                ("보험 가입", driver.insuranceSubscribed == true ? "가입완료" : "미가입"),
                ("연락 상태", approvalStatusText(currentProfile.daeriAccess) ?? "-")
            ]
        case let .store(store):
            return [
                ("매장명", store.storeName?.nilIfBlank ?? "미등록"),
                ("카테고리", storeCategoryText(store.category))
            ]
        case .none:
            return currentProfile.mode == .general ? [("현재 상태", "일반 사용자")] : []
        }
    }

    private func storeCategoryText(_ value: String?) -> String {
        switch value?.uppercased() {
        case "FOOD":
            return "맛집·카페"
        case "URGENT":
            return "SOS 긴급"
        case "LIFE":
            return "동네 편의"
        default:
            return "미등록"
        }
    }

    private func approvalStatusText(_ status: ApprovalStatus) -> String? {
        switch status {
        case .none:
            return "신청 전 상태입니다"
        case .pending:
            return "심사 진행 중입니다"
        case .approved:
            return "전환 가능합니다"
        case .rejected:
            return "이전 신청이 반려되었습니다"
        }
    }

    @ViewBuilder
    private var promoPreview: some View {
        if let data = viewModel.storePromo.localImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else if let urlString = viewModel.storePromo.remoteImageURL?.nilIfBlank,
                  let url = URL(string: urlString) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image("ic_store_promo_placeholder")
                    .resizable()
                    .scaledToFill()
            }
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color(red: 0.76, green: 0.79, blue: 0.84))

                Text("이미지 선택")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

#Preview("일반 사용자") {
    NavigationStack {
        MyPageView(
            profile: UserProfile(
                id: "preview-general",
                displayName: "Ananas L",
                mode: .general
            ),
            onRoute: { _ in }
        )
        .environmentObject(AppContainer())
    }
}

#Preview("택시 기사") {
    NavigationStack {
        MyPageView(
            profile: UserProfile(
                id: "preview-taxi",
                displayName: "백선욱",
                mode: .partnerTaxi,
                taxiAccess: .approved,
                taxiPartnerId: "taxi-preview"
            ),
            onRoute: { _ in }
        )
        .environmentObject(AppContainer())
    }
}

#Preview("대리 기사") {
    NavigationStack {
        MyPageView(
            profile: UserProfile(
                id: "preview-daeri",
                displayName: "김대리",
                mode: .partnerDaeri,
                daeriAccess: .approved,
                daeriPartnerId: "daeri-preview"
            ),
            onRoute: { _ in }
        )
        .environmentObject(AppContainer())
    }
}

#Preview("자영업 파트너") {
    NavigationStack {
        MyPageView(
            profile: UserProfile(
                id: "preview-store",
                displayName: "은하수카페",
                mode: .partnerStore,
                storeAccess: .approved,
                storePartnerId: "store-preview"
            ),
            onRoute: { _ in }
        )
        .environmentObject(AppContainer())
    }
}
