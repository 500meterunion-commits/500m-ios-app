import SwiftUI

struct MainShellView: View {
    let profile: UserProfile

    @EnvironmentObject private var deepLinkCenter: AppDeepLinkCenter
    @State private var selectedTab: MainTab = .store
    @State private var activeMapTab: MainTab = .store
    @State private var pushRoute: MainRoute?
    @State private var partnerApplyMode: UserMode?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapTabView(
                    selectedTab: $activeMapTab,
                    pendingMatchRoute: deepLinkCenter.pendingMatchRoute,
                    onConsumeMatchRoute: { route in
                        deepLinkCenter.consumeMatchRoute(route)
                    }
                )
                    .opacity(selectedTab == .mypage ? 0 : 1)
                    .allowsHitTesting(selectedTab != .mypage)
                    .ignoresSafeArea(.container, edges: .top)

                if selectedTab == .mypage {
                    Group {
                        MyPageView(profile: profile) { route in
                            switch route {
                            case let .partnerApply(mode):
                                partnerApplyMode = mode
                            default:
                                pushRoute = route
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                }

                HomeTabBar(selectedTab: $selectedTab)
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue != .mypage {
                    activeMapTab = newValue
                }
            }
            .onChange(of: deepLinkCenter.pendingMatchRoute?.id) { _, _ in
                guard let route = deepLinkCenter.pendingMatchRoute else { return }
                handleMatchDeepLink(route)
            }
            .onChange(of: deepLinkCenter.pendingPartnerApplicationRoute?.id) { _, _ in
                guard let route = deepLinkCenter.pendingPartnerApplicationRoute else { return }
                handlePartnerApplicationDeepLink(route)
            }
            .navigationDestination(item: $pushRoute) { route in
                switch route {
                case .editProfile:
                    EditProfileView()
                case .usageHistory:
                    UsageHistoryView()
                case .terms:
                    LegalDocumentView(title: "이용약관", content: TermsContent.service)
                case .privacy:
                    LegalDocumentView(title: "개인정보처리방침", content: TermsContent.partnerPrivacy)
                case .partnerApply:
                    EmptyView()
                }
            }
            .fullScreenCover(item: $partnerApplyMode) { mode in
                PartnerApplyView(mode: mode)
            }
        }
    }

    private func handleMatchDeepLink(_ route: MatchPushRoute) {
        let targetTab: MainTab? = switch route.serviceType.uppercased() {
        case "TAXI": .taxi
        case "DAERI": .daeri
        default: nil
        }

        let myDriverTab: MainTab? = switch profile.mode {
        case .partnerTaxi: .taxi
        case .partnerDaeri: .daeri
        case .general, .partnerStore: nil
        }

        switch route.type {
        case .matchRequest:
            if let myDriverTab, myDriverTab == targetTab {
                selectedTab = myDriverTab
                activeMapTab = myDriverTab
            }
        case .matchAccepted, .matchRejected, .matchCanceled, .matchExpired, .rideCompleted:
            if let targetTab {
                selectedTab = targetTab
                activeMapTab = targetTab
            }
        case .partnerApplicationApproved, .partnerApplicationRejected:
            break
        }
    }

    private func handlePartnerApplicationDeepLink(_ route: PartnerApplicationPushRoute) {
        selectedTab = .mypage
        deepLinkCenter.consumePartnerRoute(route)
    }
}

private struct HomeTabBar: View {
    @Binding var selectedTab: MainTab

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let inactive = Color(red: 0.66, green: 0.72, blue: 0.79)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Image(tab.assetName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundStyle(selectedTab == tab ? brandRed : inactive)

                        Text(tab.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selectedTab == tab ? brandRed : inactive)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(
            Rectangle()
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

enum MainRoute: Hashable, Identifiable {
    case editProfile
    case usageHistory
    case terms
    case privacy
    case partnerApply(UserMode)

    var id: String {
        switch self {
        case .editProfile: return "editProfile"
        case .usageHistory: return "usageHistory"
        case .terms: return "terms"
        case .privacy: return "privacy"
        case let .partnerApply(mode): return "partnerApply_\(mode.rawValue)"
        }
    }
}
