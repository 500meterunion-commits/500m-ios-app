import SwiftUI

struct MyPageView: View {
    let profile: UserProfile
    let onRoute: (MainRoute) -> Void

    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = MyPageViewModel()
    @State private var confirmLogout = false
    @State private var confirmWithdraw = false

    init(profile: UserProfile, onRoute: @escaping (MainRoute) -> Void) {
        self.profile = profile
        self.onRoute = onRoute
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileCard
                modeSection
                menuSection
                accountSection
            }
            .padding(20)
        }
        .navigationTitle("내 계정")
        .task {
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
        ), actions: {
            Button("확인") { viewModel.alertMessage = nil }
        }, message: {
            Text(viewModel.alertMessage ?? "")
        })
        .confirmationDialog("로그아웃 하시겠습니까?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) { viewModel.logout() }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("회원 탈퇴를 진행할까요?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
            Button("회원 탈퇴", role: .destructive) { viewModel.withdraw() }
            Button("취소", role: .cancel) {}
        }
    }

    private var profileCard: some View {
        Button {
            viewModel.requestEditProfile()
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayNameText())
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(viewModel.gradeText())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("서비스 모드")
                .font(.headline)

            modeButton(title: "택시 파트너", mode: .partnerTaxi)
            modeButton(title: "대리 파트너", mode: .partnerDaeri)
            modeButton(title: "자영업 파트너", mode: .partnerStore)
        }
    }

    private func modeButton(title: String, mode: UserMode) -> some View {
        let selected = viewModel.profile?.mode == mode

        return Button {
            viewModel.onServiceToggle(mode)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(selected ? "사용 중" : "전환")
                    .foregroundStyle(selected ? Color.green : Color.orange)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정")
                .font(.headline)

            menuRow(title: "프로필 수정") { viewModel.requestEditProfile() }
            menuRow(title: "이용 내역") { viewModel.requestUsageHistory() }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계정")
                .font(.headline)

            menuRow(title: "로그아웃") { confirmLogout = true }
            menuRow(title: "회원 탈퇴", tint: .red) { confirmWithdraw = true }
        }
    }

    private func menuRow(title: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
