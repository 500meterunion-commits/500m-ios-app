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
    @State private var shouldShowLoadingSheet = true
    @State private var sheetDragTranslation: CGFloat = 0
    @State private var kakaoPlaceIDToShow: String?

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textDark = Color(red: 0.16, green: 0.21, blue: 0.28)
    private let textMuted = Color(red: 0.67, green: 0.72, blue: 0.79)

    init(tab: MainTab) {
        self.tab = tab
        _viewModel = StateObject(wrappedValue: MapTabViewModel(tab: tab))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KakaoMapContainerView(
                    center: mapCenter,
                    radiusMeters: viewModel.radiusMeters,
                    storeMarkers: tab == .store ? filteredStores : [],
                    onStoreTap: handleStoreTap,
                    onMapTap: handleMapBackgroundTap
                )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                radiusOverlay

                if tab == .store {
                    storeCategoryRow
                }

                VStack {
                    Spacer()
                    bottomSheet(
                        maxExpandedHeight: maxExpandedSheetHeight(in: proxy),
                        containerWidth: proxy.size.width
                    )
                        .padding(.bottom, 84)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task {
            viewModel.configure(container: container)
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                shouldShowLoadingSheet = isLoading || shouldShowEmptyState
                if isLoading {
                    isSheetExpanded = true
                } else if sheetItemCount > 0 {
                    isSheetExpanded = false
                }
            }
        }
        .onChange(of: sheetItemCount) { itemCount in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                shouldShowLoadingSheet = viewModel.isLoading || itemCount == 0
                if itemCount > 0, !viewModel.isLoading {
                    isSheetExpanded = false
                } else if itemCount == 0 {
                    isSheetExpanded = true
                }
            }
        }
        .alert("안내", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { kakaoPlaceIDToShow != nil },
            set: { if !$0 { kakaoPlaceIDToShow = nil } }
        )) {
            if let placeId = kakaoPlaceIDToShow {
                KakaoPlaceDetailView(placeId: placeId)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
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
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    shouldShowLoadingSheet = true
                    isSheetExpanded = true
                }
                viewModel.cycleRadius()
            } label: {
                Capsule()
                    .fill(brandRed)
                    .frame(width: 144, height: 38)
                    .overlay {
                        HStack(spacing: 10) {
                            Image("ic_logo")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.white)

                            Text("\(viewModel.radiusMeters) 미터")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 10)
            }
            .buttonStyle(.plain)

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
                        HStack(spacing: 8) {
                            Image(category.iconName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(brandRed)

                            Text(category.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(textDark)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 24)
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
            .padding(.top, 88)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func bottomSheet(maxExpandedHeight: CGFloat, containerWidth: CGFloat) -> some View {
        let baseHeight = sheetBaseHeight(maxExpandedHeight: maxExpandedHeight)
        let collapsedVisibleHeight = collapsedSheetVisibleHeight(baseHeight: baseHeight)
        let maxCollapsedOffset = max(0, baseHeight - collapsedVisibleHeight)
        let restingOffset: CGFloat = isSheetExpanded ? 0 : maxCollapsedOffset
        let currentOffset = min(
            max(0, restingOffset + sheetDragTranslation),
            maxCollapsedOffset
        )

        return VStack(alignment: .leading, spacing: 0) {
            if shouldShowSheetTitle {
                Text(sheetTitle)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(textMuted)
                    .padding(.top, 38)
                    .padding(.horizontal, 24)
            }

            if viewModel.isLoading {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(brandRed)
                            .scaleEffect(1.25)

                        Text(emptyStateText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(textMuted)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 42)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if shouldShowEmptyState {
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
                        if tab == .store {
                            if let selectedStoreCard {
                                StoreBottomCard(
                                    store: selectedStoreCard.store,
                                    distanceText: selectedStoreCard.distanceText,
                                    onTap: { handleStoreTap(selectedStoreCard.store.id) },
                                    onMoreTap: { openStoreDetail(selectedStoreCard.store) }
                                )
                            } else {
                                ForEach(storeListCards, id: \.id) { store in
                                    StoreBottomCard(
                                        store: store,
                                        distanceText: storeDistanceText(for: store),
                                        onTap: { handleStoreTap(store.id) },
                                        onMoreTap: { openStoreDetail(store) }
                                    )
                                }
                            }
                        } else {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: containerWidth)
        .frame(height: baseHeight)
        .background(.white, in: TopRoundedRectangle(radius: 28))
        .shadow(color: .black.opacity(0.08), radius: 18, y: -6)
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color(red: 0.82, green: 0.86, blue: 0.90))
                .frame(width: 62, height: 8)
                .padding(.top, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        if isSheetExpanded {
                            collapseSheet()
                        } else {
                            isSheetExpanded = true
                        }
                    }
                }
        }
        .clipped()
        .offset(y: currentOffset)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    sheetDragTranslation = value.translation.height
                }
                .onEnded { value in
                    guard maxCollapsedOffset > 0 else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        if value.translation.height > 44 {
                            collapseSheet()
                        } else if value.translation.height < -44 {
                            isSheetExpanded = true
                        }
                        sheetDragTranslation = 0
                    }
                }
        )
    }

    private var sheetTitle: String {
        switch tab {
        case .store: return "주변 가게 목록"
        case .taxi, .daeri: return "주변 기사 목록"
        case .mypage: return ""
        }
    }

    private var shouldShowSheetTitle: Bool {
        if isSelectedStoreSheet {
            return false
        }
        return true
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
            return filteredStores.isEmpty
        case .taxi:
            return viewModel.drivers.isEmpty
        case .daeri:
            return viewModel.drivers.isEmpty
        case .mypage:
            return true
        }
    }

    private func sheetBaseHeight(maxExpandedHeight: CGFloat) -> CGFloat {
        if viewModel.isLoading {
            return min(300, maxExpandedHeight)
        }

        if isSelectedStoreSheet {
            return min(maxExpandedHeight, 500)
        }

        let hasData = sheetItemCount > 0
        if hasData {
            return maxExpandedHeight
        }
        return shouldShowLoadingSheet ? min(300, maxExpandedHeight) : 118
    }

    private func collapsedSheetVisibleHeight(baseHeight: CGFloat) -> CGFloat {
        if viewModel.isLoading {
            return baseHeight
        }

        if isSelectedStoreSheet {
            return 34
        }

        if sheetItemCount > 0 {
            return 34
        }

        return baseHeight
    }

    private func maxExpandedSheetHeight(in proxy: GeometryProxy) -> CGFloat {
        let reservedBottomSpace: CGFloat = 96
        return max(320, proxy.size.height - reservedBottomSpace)
    }

    private var sheetItemCount: Int {
        switch tab {
        case .store:
            return filteredStores.count
        case .taxi, .daeri:
            return listItems.count
        case .mypage:
            return 0
        }
    }

    private var listItems: [HomeListItem] {
        switch tab {
        case .store:
            return []
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

    private func handleStoreTap(_ storeID: String) {
        guard let store = filteredStores.first(where: { $0.id == storeID }) else { return }
        viewModel.selectStore(store)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isSheetExpanded = true
            sheetDragTranslation = 0
        }
    }

    private func handleMapBackgroundTap() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            collapseSheet()
        }
    }

    private func openStoreDetail(_ store: StoreMarker) {
        viewModel.selectStore(store)
        collapseSheet()
        if !store.kakaoStoreRegId.isEmpty {
            kakaoPlaceIDToShow = store.kakaoStoreRegId
            return
        }
        if let url = kakaoStoreURL(for: store) {
            openURL(url)
        }
    }

    private func storeDistanceText(for store: StoreMarker) -> String {
        guard let user = viewModel.userLocation else { return "근처" }
        let meters = Int(GeoMath.haversineMeters(user.lat, user.lng, store.lat, store.lng))
        return "\(meters)m 이내"
    }

    private var selectedStoreCard: (store: StoreMarker, distanceText: String)? {
        guard case let .store(store) = viewModel.selected else { return nil }
        return (store, storeDistanceText(for: store))
    }

    private var isSelectedStoreSheet: Bool {
        tab == .store && selectedStoreCard != nil
    }

    private var storeListCards: [StoreMarker] {
        Array(filteredStores.prefix(8))
    }

    private func collapseSheet() {
        isSheetExpanded = false
        sheetDragTranslation = 0
        if isSelectedStoreSheet {
            viewModel.clearSelection()
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

private struct StoreBottomCard: View {
    let store: StoreMarker
    let distanceText: String
    let onTap: () -> Void
    let onMoreTap: () -> Void

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textDark = Color(red: 0.16, green: 0.21, blue: 0.28)
    private let textMuted = Color(red: 0.67, green: 0.72, blue: 0.79)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let urlString = store.promoImageURL?.nilIfBlank,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image("ic_store_promo_placeholder")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                } else {
                    Image("ic_store_promo_placeholder")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 18)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 12) {
                Text(store.storeName?.nilIfBlank ?? "가게")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(textDark)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(textMuted)

                    Text(distanceText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(textMuted)
                }

                Text(store.promoText?.nilIfBlank ?? "설명이 없습니다.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.35, blue: 0.45))
                    .lineSpacing(4)
                    .lineLimit(3)

                Button(action: onMoreTap) {
                    HStack(spacing: 10) {
                        Text("더보기")
                            .font(.system(size: 18, weight: .heavy))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(brandRed, in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 28))
        .onTapGesture(perform: onTap)
    }
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
