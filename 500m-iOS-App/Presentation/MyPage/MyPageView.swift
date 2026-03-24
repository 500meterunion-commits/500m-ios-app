import SwiftUI

struct MyPageView: View {
    let profile: UserProfile
    let onRoute: (MainRoute) -> Void

    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = MyPageViewModel()
    @State private var confirmLogout = false
    @State private var confirmWithdraw = false

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
        let currentMode = currentProfile.mode
        if currentMode == .general { return true }
        return currentMode == mode
    }

    private func gradeText(for mode: UserMode) -> String {
        switch mode {
        case .general: return "일반 사용자"
        case .partnerTaxi: return "택시 기사"
        case .partnerDaeri: return "대리 기사"
        case .partnerStore: return "자영업 파트너"
        }
    }

    private func serviceToggleRow(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
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
        if let urlString = currentProfile.userProfileURL?.nilIfBlank, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
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
