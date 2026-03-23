import SwiftUI

struct ServiceRootView: View {
    let tab: MainTab

    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ServiceRootViewModel

    init(tab: MainTab) {
        self.tab = tab
        _viewModel = StateObject(wrappedValue: ServiceRootViewModel(tab: tab))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                switch tab {
                case .store:
                    nearbyStoreSection
                case .taxi, .daeri:
                    nearbyDriverSection
                case .mypage:
                    EmptyView()
                }
            }
            .padding(20)
        }
        .navigationTitle(tab.title)
        .task {
            viewModel.configure(container: container)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tab.title)
                .font(.title2.bold())

            if let location = viewModel.userLocation {
                Text("현재 위치: \(location.lat.formatted(.number.precision(.fractionLength(4)))), \(location.lng.formatted(.number.precision(.fractionLength(4))))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("위치 권한을 허용하면 주변 파트너를 불러옵니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.95, blue: 0.92), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var nearbyStoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("주변 가게")
                .font(.headline)

            if viewModel.stores.isEmpty {
                emptyState("반경 500m 안에 표시할 가게가 아직 없습니다.")
            } else {
                ForEach(viewModel.stores) { store in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.storeName?.nilIfBlank ?? "가게")
                            .font(.headline)
                        Text(store.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let promoText = store.promoText?.nilIfBlank {
                            Text(promoText)
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var nearbyDriverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tab == .taxi ? "주변 택시 기사" : "주변 대리 기사")
                .font(.headline)

            if viewModel.drivers.isEmpty {
                emptyState("반경 500m 안에 표시할 파트너가 아직 없습니다.")
            } else {
                ForEach(viewModel.drivers) { driver in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.46, blue: 0.28))
                            .frame(width: 12, height: 12)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(driver.name?.nilIfBlank ?? "파트너")
                                .font(.headline)
                            if let carNumber = driver.carNumber?.nilIfBlank {
                                Text(carNumber)
                                    .font(.subheadline)
                            }
                            Text("상태: \(driver.status)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
