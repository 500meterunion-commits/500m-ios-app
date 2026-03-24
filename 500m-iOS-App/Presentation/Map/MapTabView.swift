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
    @Binding var selectedTab: MainTab

    @EnvironmentObject private var container: AppContainer
    @Environment(\.openURL) private var openURL
    @StateObject private var storeViewModel = MapTabViewModel(tab: .store)
    @StateObject private var taxiViewModel = MapTabViewModel(tab: .taxi)
    @StateObject private var daeriViewModel = MapTabViewModel(tab: .daeri)
    @State private var selectedStoreCategories = Set(StoreCategoryFilter.allCases)
    @State private var isSheetExpanded = true
    @State private var shouldShowLoadingSheet = true
    @State private var sheetDragTranslation: CGFloat = 0
    @State private var kakaoPlaceIDToShow: String?
    @State private var completedInitialStoreLoad = false
    @State private var completedInitialTaxiLoad = false
    @State private var completedInitialDaeriLoad = false

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textDark = Color(red: 0.16, green: 0.21, blue: 0.28)
    private let textMuted = Color(red: 0.67, green: 0.72, blue: 0.79)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KakaoMapContainerView(
                    center: mapCenter,
                    radiusMeters: viewModel.radiusMeters,
                    storeMarkers: tab == .store ? filteredStores : [],
                    driverMarkers: tab == .taxi || tab == .daeri ? viewModel.drivers : [],
                    onStoreTap: handleStoreTap,
                    onDriverTap: handleDriverTap,
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
            storeViewModel.configure(container: container)
            taxiViewModel.configure(container: container)
            daeriViewModel.configure(container: container)
            shouldShowLoadingSheet = shouldAutoShowLoadingSheet
        }
        .onChange(of: tab) { _, _ in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                shouldShowLoadingSheet = shouldAutoShowLoadingSheet
                isSheetExpanded = selectedPartnerCardVisible
                sheetDragTranslation = 0
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                markInitialLoadCompleted(for: tab)
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                shouldShowLoadingSheet = shouldAutoShowLoadingSheet
                if isLoading && shouldAutoShowLoadingSheet {
                    isSheetExpanded = true
                } else {
                    isSheetExpanded = selectedPartnerCardVisible
                }
            }
        }
        .onChange(of: sheetItemCount) { _, itemCount in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                shouldShowLoadingSheet = shouldAutoShowLoadingSheet
                if !viewModel.isLoading, !selectedPartnerCardVisible {
                    isSheetExpanded = false
                }
            }
        }
        .onChange(of: viewModel.selected?.id) { _, _ in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                if selectedPartnerCardVisible {
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

    private var tab: MainTab { selectedTab }

    private var viewModel: MapTabViewModel {
        switch tab {
        case .store:
            return storeViewModel
        case .taxi:
            return taxiViewModel
        case .daeri:
            return daeriViewModel
        case .mypage:
            return storeViewModel
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
        storeViewModel.stores.filter { store in
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
                    .frame(width: 144, height: 58)
                    .overlay {
                        HStack(spacing: 10) {
                            Image("ic_logo")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.white)

                            Text("\(viewModel.radiusMeters) 미터")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 50)
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
                                .frame(width: 18, height: 18)
                                .foregroundStyle(brandRed)

                            Text(category.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(textDark)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.white, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    selectedStoreCategories.contains(category)
                                        ? brandRed
                                        : Color.black.opacity(0.08),
                                    lineWidth: selectedStoreCategories.contains(category) ? 2 : 1
                                )
                        }
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 130)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func bottomSheet(maxExpandedHeight: CGFloat, containerWidth: CGFloat) -> some View {
        let baseHeight = sheetBaseHeight(maxExpandedHeight: maxExpandedHeight)
        let collapsedVisibleHeight = collapsedSheetVisibleHeight(baseHeight: baseHeight)
        let maxCollapsedOffset = max(0, baseHeight - collapsedVisibleHeight)
        let restingOffset: CGFloat = isSheetExpanded ? 0 : maxCollapsedOffset
        let currentOffset = min(max(0, restingOffset + sheetDragTranslation), maxCollapsedOffset)

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
                        } else if let selectedDriverData {
                            DriverSelectedCard(
                                data: selectedDriverData,
                                isSubmitting: viewModel.isSubmitting,
                                onClose: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                        collapseSheet()
                                    }
                                },
                                onRequest: {
                                    viewModel.requestSelectedDriver()
                                }
                            )
                        } else {
                            ForEach(listItems, id: \.id) { item in
                                Button {
                                    handleListTap(item)
                                } label: {
                                    DriverListRow(
                                        item: item,
                                        accent: brandRed,
                                        textDark: textDark,
                                        textMuted: textMuted
                                    )
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
        !(isSelectedStoreSheet || isSelectedDriverSheet)
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
        case .store, .taxi, .daeri:
            return "주위에 파트너 데이터가 없습니다."
        case .mypage:
            return ""
        }
    }

    private var shouldShowEmptyState: Bool {
        switch tab {
        case .store:
            return filteredStores.isEmpty
        case .taxi, .daeri:
            return viewModel.drivers.isEmpty
        case .mypage:
            return true
        }
    }

    private var shouldAutoShowLoadingSheet: Bool {
        viewModel.isLoading && !hasCompletedInitialLoad(for: tab)
    }

    private func sheetBaseHeight(maxExpandedHeight: CGFloat) -> CGFloat {
        if viewModel.isLoading {
            return min(300, maxExpandedHeight)
        }

        if isSelectedStoreSheet {
            return min(maxExpandedHeight, 500)
        }

        if isSelectedDriverSheet {
            return min(maxExpandedHeight, 380)
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

        if isSelectedStoreSheet || isSelectedDriverSheet || sheetItemCount > 0 || shouldShowEmptyState {
            return 34
        }

        return baseHeight
    }

    private func maxExpandedSheetHeight(in proxy: GeometryProxy) -> CGFloat {
        let reservedBottomSpace: CGFloat = 96
        let reservedTopSpace: CGFloat = 140
        return max(320, proxy.size.height - reservedBottomSpace - reservedTopSpace)
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
                    subtitle: driverListSubtitle(for: driver),
                    iconName: tab == .taxi ? "tab_taxi" : "tab_daeri",
                    tint: brandRed
                )
            }
        case .mypage:
            return []
        }
    }

    private func handleListTap(_ item: HomeListItem) {
        guard let driver = viewModel.drivers.first(where: { $0.id == item.id }) else { return }
        viewModel.selectDriver(driver)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isSheetExpanded = true
            sheetDragTranslation = 0
        }
    }

    private func handleStoreTap(_ storeID: String) {
        guard let store = filteredStores.first(where: { $0.id == storeID }) else { return }
        storeViewModel.selectStore(store)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isSheetExpanded = true
            sheetDragTranslation = 0
        }
    }

    private func handleDriverTap(_ driverID: String) {
        guard let driver = viewModel.drivers.first(where: { $0.id == driverID }) else { return }
        viewModel.selectDriver(driver)
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

    private func hasCompletedInitialLoad(for tab: MainTab) -> Bool {
        switch tab {
        case .store:
            return completedInitialStoreLoad
        case .taxi:
            return completedInitialTaxiLoad
        case .daeri:
            return completedInitialDaeriLoad
        case .mypage:
            return true
        }
    }

    private func markInitialLoadCompleted(for tab: MainTab) {
        switch tab {
        case .store:
            completedInitialStoreLoad = true
        case .taxi:
            completedInitialTaxiLoad = true
        case .daeri:
            completedInitialDaeriLoad = true
        case .mypage:
            break
        }
    }

    private func openStoreDetail(_ store: StoreMarker) {
        storeViewModel.selectStore(store)
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
        guard let user = storeViewModel.userLocation else { return "근처" }
        let meters = Int(GeoMath.haversineMeters(user.lat, user.lng, store.lat, store.lng))
        return "\(meters)m 이내"
    }

    private var selectedStoreCard: (store: StoreMarker, distanceText: String)? {
        guard tab == .store, case let .store(store) = storeViewModel.selected else { return nil }
        return (store, storeDistanceText(for: store))
    }

    private var selectedDriverData: DriverSelectedCardData? {
        guard (tab == .taxi || tab == .daeri),
              case let .driver(driver) = viewModel.selected else { return nil }

        let partnerInfo = viewModel.selectedPartnerInfo
        let name: String
        let memo: String
        let profileImageURL: String?
        let insuranceJoined: Bool?
        let carNumber: String?

        switch partnerInfo {
        case let .taxi(info):
            name = info.name?.nilIfBlank ?? driver.name?.nilIfBlank ?? "택시 기사"
            memo = info.memo?.nilIfBlank ?? "안전하고 신속하게 모시겠습니다."
            profileImageURL = info.photoURL?.nilIfBlank
            insuranceJoined = nil
            carNumber = info.carNumber?.nilIfBlank ?? driver.carNumber?.nilIfBlank
        case let .daeri(info):
            name = info.name?.nilIfBlank ?? driver.name?.nilIfBlank ?? "대리 기사"
            memo = info.memo?.nilIfBlank ?? "안전하고 신속하게 모시겠습니다."
            profileImageURL = info.photoURL?.nilIfBlank
            insuranceJoined = info.insuranceSubscribed
            carNumber = nil
        case .store, .none:
            name = driver.name?.nilIfBlank ?? (tab == .taxi ? "택시 기사" : "대리 기사")
            memo = "안전하고 신속하게 모시겠습니다."
            profileImageURL = nil
            insuranceJoined = driver.insuranceSubscribed
            carNumber = driver.carNumber?.nilIfBlank
        }

        return DriverSelectedCardData(
            name: name,
            memo: memo,
            profileImageURL: profileImageURL,
            etaText: viewModel.routeEtaText,
            distanceText: driverDistanceText(for: driver),
            carNumber: carNumber,
            insuranceJoined: insuranceJoined,
            isTaxi: tab == .taxi
        )
    }

    private var isSelectedStoreSheet: Bool {
        tab == .store && selectedStoreCard != nil
    }

    private var isSelectedDriverSheet: Bool {
        (tab == .taxi || tab == .daeri) && selectedDriverData != nil
    }

    private var selectedPartnerCardVisible: Bool {
        isSelectedStoreSheet || isSelectedDriverSheet
    }

    private var storeListCards: [StoreMarker] {
        Array(filteredStores.prefix(8))
    }

    private func collapseSheet() {
        isSheetExpanded = false
        sheetDragTranslation = 0
        if isSelectedStoreSheet || isSelectedDriverSheet {
            viewModel.clearSelection()
        }
    }

    private func kakaoStoreURL(for store: StoreMarker) -> URL? {
        if !store.kakaoStoreRegId.isEmpty {
            return URL(string: "kakaomap://place?id=\(store.kakaoStoreRegId)")
        }
        return URL(string: "kakaomap://look?p=\(store.lat),\(store.lng)")
    }

    private func driverDistanceText(for driver: DriverMarker) -> String {
        guard let user = viewModel.userLocation else { return "근처" }
        let meters = Int(GeoMath.haversineMeters(user.lat, user.lng, driver.lat, driver.lng))
        return "\(meters)m 이내"
    }

    private func driverListSubtitle(for driver: DriverMarker) -> String {
        if tab == .taxi {
            return "\(driver.carNumber?.nilIfBlank ?? "차량 번호 미등록")  ·  \(driverDistanceText(for: driver))"
        }
        let insuranceText = driver.insuranceSubscribed == true ? "보험 가입완료" : "보험 정보 확인중"
        return "\(insuranceText)  ·  \(driverDistanceText(for: driver))"
    }
}

private struct HomeListItem {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let tint: Color
}

private struct DriverSelectedCardData {
    let name: String
    let memo: String
    let profileImageURL: String?
    let etaText: String
    let distanceText: String
    let carNumber: String?
    let insuranceJoined: Bool?
    let isTaxi: Bool
}

private struct DriverListRow: View {
    let item: HomeListItem
    let accent: Color
    let textDark: Color
    let textMuted: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(item.iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            Text(item.title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(textDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 34)

            Text(item.subtitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textDark)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

private struct DriverSelectedCard: View {
    let data: DriverSelectedCardData
    let isSubmitting: Bool
    let onClose: () -> Void
    let onRequest: () -> Void

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let textDark = Color(red: 0.07, green: 0.09, blue: 0.14)
    private let textMuted = Color(red: 0.60, green: 0.65, blue: 0.73)
    private let green = Color(red: 0.19, green: 0.77, blue: 0.42)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let urlString = data.profileImageURL,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().scaledToFill()
                                default:
                                    Image("ic_profile_placeholder")
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        } else {
                            Image("ic_profile_placeholder")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle()
                                .fill(green)
                                .padding(3)
                        }
                        .offset(x: 5, y: 5)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(data.name)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(textDark)

                    Text(data.memo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textMuted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 0) {
                MetricColumn(title: "도착 예상", value: data.etaText, valueColor: textDark)

                Divider()
                    .frame(height: 56)

                MetricColumn(
                    title: data.isTaxi ? "자동차 번호" : "보험 가입 여부",
                    value: data.isTaxi ? (data.carNumber ?? "—") : (data.insuranceJoined == true ? "가입완료" : "미가입"),
                    valueColor: data.isTaxi ? brandRed : (data.insuranceJoined == true ? brandRed : textDark)
                )

                Divider()
                    .frame(height: 56)

                MetricColumn(title: "현재 위치", value: data.distanceText, valueColor: textDark)
            }
            .padding(.top, 20)

            HStack(spacing: 14) {
                Button(action: onClose) {
                    Text("닫기")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.39))
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(.white, in: RoundedRectangle(cornerRadius: 28))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color(red: 0.84, green: 0.87, blue: 0.91), lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)

                Button(action: onRequest) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(brandRed)
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("서비스 신청")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

private struct MetricColumn: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.60, green: 0.65, blue: 0.73))

            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
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
