import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: AppSessionStore
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPartnerInfo = false

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textGray = Color(red: 0.48, green: 0.53, blue: 0.58)
    private let captionGray = Color(red: 0.60, green: 0.65, blue: 0.70)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.white
                    .ignoresSafeArea()

                loginContent(proxy: proxy)
                    .opacity(showPartnerInfo ? 0.18 : 1)
                    .animation(.easeInOut(duration: 0.22), value: showPartnerInfo)

                if showPartnerInfo {
                    partnerInfoPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }

                if case let .loading(message) = viewModel.state {
                    loadingOverlay(message: message)
                        .zIndex(2)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: showPartnerInfo)
        }
        .task {
            viewModel.configure(container: container)
        }
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .success {
                session.refreshProfile()
            }
        }
        .alert("로그인 오류", isPresented: Binding(
            get: {
                if case .failure = viewModel.state { return true }
                return false
            },
            set: { newValue in
                if !newValue { viewModel.clearError() }
            }
        ), actions: {
            Button("확인") { viewModel.clearError() }
        }, message: {
            if case let .failure(message) = viewModel.state {
                Text(message)
            }
        })
    }

    private func loginContent(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: max(56, proxy.size.height * 0.11))

            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image("ic_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)

                    Text("500m")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(brandRed)
                }

                Text("500m 안의 모든 것을 발견하세요")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(textGray)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: max(110, proxy.size.height * 0.24))

            VStack(spacing: 14) {
                SocialOutlineButton(
                    title: "Google로 계속하기",
                    borderColor: Color(red: 0.30, green: 0.55, blue: 0.96),
                    contentColor: Color(red: 0.30, green: 0.55, blue: 0.96),
                    imageName: "ic_google",
                    fallbackSystemName: "globe"
                ) {
                    viewModel.signInWithGoogle()
                }

                SocialOutlineButton(
                    title: "카카오로 계속하기",
                    borderColor: Color(red: 0.95, green: 0.76, blue: 0.00),
                    contentColor: Color(red: 0.23, green: 0.16, blue: 0.10),
                    imageName: "ic_kakao",
                    fallbackSystemName: "message.fill"
                ) {
                    viewModel.signInWithKakao()
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: max(120, proxy.size.height * 0.20))

            VStack(spacing: 10) {
                Text("회원가입 시 \"일반 이용자\"로 등록됩니다.\n\"파트너스\"활동은 인증 후 가능합니다.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(captionGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Button {
                    showPartnerInfo = true
                } label: {
                    Text("파트너스 알아보기")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(brandRed)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 18)
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
    }

    private var partnerInfoPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    showPartnerInfo = false
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Text("파트너스 알아보기")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("500m 파트너스란?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    Text(partnerInfoText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(red: 0.23, green: 0.25, blue: 0.28))
                        .lineSpacing(10)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
    }

    private func loadingOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text(message)
                    .font(.subheadline)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var partnerInfoText: String {
        """
        🏠 자영업자 파트너 (음식점, 카페, 서비스업 등)

        초밀착 홍보:매장 반경 500m 내에 있는 잠재 고객에게 실시간 이벤트/쿠폰 노출
        방문율 증대:위치 기반 알림을 통해 유동 인구를 실제 매장 방문객으로 전환
        광고비 절감: 불특정 다수가 아닌, 바로 근처 고객에게만 타겟팅하여 효율적인 마케팅 가능

         🚕 택시 & 🚙 대리기사 파트너
        공차 시간 최소화: 현재 내 위치에서 가장 가까운 호출을 우선 배차하여 이동 거리 단축
        스마트 동선 최적화: 500m 이내의 짧은 대기 동선으로 운행 효율 극대화
        수수료 0원: 파트너 기사님을 위한 수수료 0원. 월 구독료 5000원

         🚀 왜 500미터 파트너스인가요?
        1. 가장 가까운 연결: 멀리 있는 고객을 찾을 필요 없습니다.
        2. 바로 옆에 있는 고객이 파트너님의 서비스를 기다립니다.
        3. 간편한 관리: 복잡한 설정 없이 앱 하나로 매장 홍보부터 배차 확인까지 한 번에 해결하세요.

        🛠️ 파트너 가입 절차택시 네트워크
        1. 가입 신청:앱 내 '파트너 신청' 메뉴에서 정보 입력
        2. 서류 확인: 사업자 등록증 또는 면허증 확인 (최대 48시간 소요)
        3. 승인 완료: 파트너 전용 모드 활성화 및 즉시 활동 시작!

         500미터와 함께라면 당신의 비즈니스가 더 가까워집니다.
        """
    }
}

private struct SocialOutlineButton: View {
    let title: String
    let borderColor: Color
    let contentColor: Color
    let imageName: String
    let fallbackSystemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Spacer(minLength: 18)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: fallbackSystemName)
                            .opacity(0.0001)
                    }

                Spacer(minLength: 14)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(contentColor)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 42)
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(borderColor, lineWidth: 1.8)
            )
        }
        .buttonStyle(.plain)
    }
}
