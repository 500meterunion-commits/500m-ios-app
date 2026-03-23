import SwiftUI

struct MainShellView: View {
    let profile: UserProfile

    @State private var selectedTab: MainTab = .store
    @State private var route: MainRoute?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .store:
                        MapTabView(tab: .store)
                    case .taxi:
                        MapTabView(tab: .taxi)
                    case .daeri:
                        MapTabView(tab: .daeri)
                    case .mypage:
                        MyPageView(profile: profile) { route = $0 }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HomeTabBar(selectedTab: $selectedTab)
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .editProfile:
                    EditProfileView()
                case .usageHistory:
                    UsageHistoryView()
                case let .partnerApply(mode):
                    PartnerApplyView(mode: mode)
                }
            }
        }
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
    case partnerApply(UserMode)

    var id: String {
        switch self {
        case .editProfile: return "editProfile"
        case .usageHistory: return "usageHistory"
        case let .partnerApply(mode): return "partnerApply_\(mode.rawValue)"
        }
    }
}
