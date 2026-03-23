import SwiftUI

private enum StoreCategoryFilter: String, CaseIterable, Identifiable {
    case life = "LIFE"
    case food = "FOOD"
    case urgent = "URGENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .life: return "동네 편의"
        case .food: return "맛집·카페"
        case .urgent: return "SOS 긴급"
        }
    }

    var iconName: String {
        switch self {
        case .life: return "ic_life"
        case .food: return "ic_food"
        case .urgent: return "ic_urgent"
        }
    }
}

struct MapTabView: View {
    let tab: MainTab

    @EnvironmentObject private var container: AppContainer
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: MapTabViewModel
    @State private var selectedStoreCategories = Set(StoreCategoryFilter.allCases)
    @State private var isSheetExpanded = true
    @GestureState private var sheetDragOffset: CGFloat = 0

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textDark = Color(red: 0.16, green: 0.21, blue: 0.28)
    private let textMuted = Color(red: 0.67, green: 0.72, blue: 0.79)

    init(tab: MainTab) {
        self.tab = tab
        _viewModel = StateObject(wrappedValue: MapTabViewModel(tab: tab))
    }

    var body: some View {
        ZStack {
            KakaoMapContainerView(center: mapCenter)
                .ignoresSafeArea()

            radiusOverlay

            if tab == .store {
                storeCategoryRow
            }

            userLocationOverlay

            VStack {
                Spacer()
                bottomSheet
                    .padding(.bottom, 80)
            }
        }
        .task {
            viewModel.configure(container: container)
        }
        .alert("안내", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var mapCenter: LatLng? {
        if let user = viewModel.userLocation {
            return user
        }
        if let driver = viewModel.trackedDriverLocation {
            return LatLng(lat: driver.lat, lng: driver.lng)
        }
        return nil
    }

    private var filteredStores: [StoreMarker] {
        viewModel.stores.filter { store in
            guard let category = StoreCategoryFilter(rawValue: store.category) else { return false }
            return selectedStoreCategories.contains(category)
        }
    }

    private var radiusOverlay: some View {
        VStack(spacing: 18) {
            Button {
                viewModel.cycleRadius()
            } label: {
                Capsule()
                    .fill(brandRed)
                    .frame(width: 180, height: 76)
                    .overlay {
                        HStack(spacing: 14) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)

                            Text("\(viewModel.radiusMeters) 미터")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.top, 72)

            Spacer()
        }
    }

    private var storeCategoryRow: some View {
        VStack {
            HStack(spacing: 12) {
                ForEach(StoreCategoryFilter.allCases) { category in
                    Button {
                        if selectedStoreCategories.contains(category) {
                            selectedStoreCategories.remove(category)
                        } else {
                            selectedStoreCategories.insert(category)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(category.iconName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(brandRed)

                            Text(category.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(textDark)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(.white, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(selectedStoreCategories.contains(category) ? brandRed : Color.black.opacity(0.08), lineWidth: selectedStoreCategories.contains(category) ? 2 : 1)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 166)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var userLocationOverlay: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(brandRed.opacity(0.12))
                    .frame(width: radiusCircleSize, height: radiusCircleSize)
                Circle()
                    .stroke(brandRed.opacity(0.4), lineWidth: 2)
                    .frame(width: radiusCircleSize, height: radiusCircleSize)

                Image("ic_my_red_dot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .padding(.bottom, 290)
        }
        .allowsHitTesting(false)
    }

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(red: 0.82, green: 0.86, blue: 0.90))
                .frame(width: 62, height: 8)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isSheetExpanded.toggle()
                    }
                }

            Text(sheetTitle)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(textDark)
                .padding(.top, 28)
                .padding(.horizontal, 24)

            if shouldShowEmptyState {
                Text(emptyStateText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textMuted)
                    .padding(.horizontal, 24)
                    .padding(.top, 42)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(listItems, id: \.id) { item in
                            Button {
                                handleListTap(item)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(item.iconName)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 26, height: 26)
                                        .foregroundStyle(item.tint)
                                        .frame(width: 44, height: 44)
                                        .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(textDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(item.subtitle)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(textMuted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if item.showAction {
                                        Text(item.actionTitle)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .frame(height: 34)
                                            .background(brandRed, in: Capsule())
                                    }
                                }
                                .padding(16)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: bottomSheetHeight)
        .background(.white, in: TopRoundedRectangle(radius: 28))
        .shadow(color: .black.opacity(0.08), radius: 18, y: -6)
        .offset(y: max(0, sheetDragOffset))
        .gesture(
            DragGesture(minimumDistance: 6)
                .updating($sheetDragOffset) { value, state, _ in
                    if value.translation.height > 0 || isSheetExpanded {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    let shouldCollapse = value.translation.height > 40
                    let shouldExpand = value.translation.height < -40
                    if shouldCollapse {
                        isSheetExpanded = false
                    } else if shouldExpand {
                        isSheetExpanded = true
                    }
                }
        )
        .animation(.easeInOut(duration: 0.22), value: bottomSheetHeight)
    }

    private var sheetTitle: String {
        switch tab {
        case .store: return "주변 가게 목록"
        case .taxi, .daeri: return "주변 기사 목록"
        case .mypage: return ""
        }
    }

    private var emptyStateText: String {
        if viewModel.isLoading {
            switch tab {
            case .store:
                return "\(viewModel.radiusMeters)미터 안의 할인매장 정보를 찾고 있습니다..."
            case .taxi:
                return "\(viewModel.radiusMeters)미터 안의 택시를 찾고 있습니다..."
            case .daeri:
                return "\(viewModel.radiusMeters)미터 안의 대리를 찾고 있습니다..."
            case .mypage:
                return ""
            }
        }

        switch tab {
        case .store:
            return "주위에 파트너 데이터가 없습니다."
        case .taxi:
            return "주위에 파트너 데이터가 없습니다."
        case .daeri:
            return "주위에 파트너 데이터가 없습니다."
        case .mypage:
            return ""
        }
    }

    private var shouldShowEmptyState: Bool {
        switch tab {
        case .store:
            return viewModel.isLoading || filteredStores.isEmpty
        case .taxi:
            return viewModel.isLoading || viewModel.drivers.isEmpty
        case .daeri:
            return viewModel.isLoading || viewModel.drivers.isEmpty
        case .mypage:
            return true
        }
    }

    private var bottomSheetHeight: CGFloat {
        let hasData = !viewModel.isLoading && !shouldShowEmptyState && !listItems.isEmpty
        if hasData {
            return isSheetExpanded ? 320 : 64
        }
        return 320
    }

    private var radiusCircleSize: CGFloat {
        switch viewModel.radiusMeters {
        case 100:
            return 130
        case 300:
            return 210
        default:
            return 270
        }
    }

    private var listItems: [HomeListItem] {
        switch tab {
        case .store:
            return filteredStores.prefix(8).map { store in
                HomeListItem(
                    id: store.id,
                    title: store.storeName?.nilIfBlank ?? "가게",
                    subtitle: store.promoText?.nilIfBlank ?? "주변 할인 매장",
                    iconName: iconName(for: store.category),
                    tint: brandRed,
                    showAction: true,
                    actionTitle: "보기"
                )
            }
        case .taxi, .daeri:
            return viewModel.drivers.prefix(8).map { driver in
                HomeListItem(
                    id: driver.id,
                    title: driver.name?.nilIfBlank ?? (tab == .taxi ? "택시 기사" : "대리 기사"),
                    subtitle: driver.carNumber?.nilIfBlank ?? "주변 이동 파트너",
                    iconName: tab == .taxi ? "tab_taxi" : "tab_daeri",
                    tint: brandRed,
                    showAction: true,
                    actionTitle: tab == .taxi ? "호출" : "호출"
                )
            }
        case .mypage:
            return []
        }
    }

    private func iconName(for category: String) -> String {
        switch category {
        case "LIFE": return "ic_life"
        case "FOOD": return "ic_food"
        case "URGENT": return "ic_urgent"
        default: return "ic_life"
        }
    }

    private func handleListTap(_ item: HomeListItem) {
        switch tab {
        case .store:
            guard let store = filteredStores.first(where: { $0.id == item.id }) else { return }
            viewModel.selectStore(store)
            if let url = kakaoStoreURL(for: store) {
                openURL(url)
            }
        case .taxi, .daeri:
            guard let driver = viewModel.drivers.first(where: { $0.id == item.id }) else { return }
            viewModel.selectDriver(driver)
            viewModel.requestSelectedDriver()
        case .mypage:
            break
        }
    }

    private func kakaoStoreURL(for store: StoreMarker) -> URL? {
        if !store.kakaoStoreRegId.isEmpty {
            return URL(string: "kakaomap://place?id=\(store.kakaoStoreRegId)")
        }
        return URL(string: "kakaomap://look?p=\(store.lat),\(store.lng)")
    }
}

private struct HomeListItem {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let tint: Color
    let showAction: Bool
    let actionTitle: String
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
