import PhotosUI
import SwiftUI

struct PartnerApplyView: View {
    let mode: UserMode

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PartnerApplyViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPlaceSearch = false

    init(mode: UserMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: PartnerApplyViewModel(mode: mode))
    }

    var body: some View {
        Form {
            if let status = viewModel.currentStatus {
                Section("신청 상태") {
                    Text(status.koreanText)
                    if let rejectReason = viewModel.rejectReason?.nilIfBlank {
                        Text(rejectReason)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("기본 정보") {
                TextField("이름", text: $viewModel.name)
                TextField("생년월일", text: $viewModel.birthDate)
                TextField("연락처", text: $viewModel.contact)
                Picker("활동 지역", selection: $viewModel.marketID) {
                    Text("부산").tag("busan")
                    Text("울산").tag("ulsan")
                }
            }

            modeSpecificSection

            Section("인증서류") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Text("서류 이미지 선택")
                }

                ForEach(viewModel.documents) { document in
                    Text(document.fileName)
                }
            }

            Section {
                Toggle("파트너 약관에 동의합니다.", isOn: $viewModel.agreePartnerTerms)
            }

            Section {
                Button(viewModel.isSubmitting ? "제출중..." : "신청서 제출") {
                    viewModel.submit()
                }
                .disabled(viewModel.isSubmitting || !viewModel.canSubmit)
            }
        }
        .navigationTitle(mode.titleForApply)
        .task {
            viewModel.configure(container: container)
        }
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchSheet { place in
                viewModel.selectedPlace = place
            }
            .environmentObject(container)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                var drafts: [PartnerApplyViewModel.DocumentDraft] = []
                for (index, item) in newItems.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        drafts.append(
                            PartnerApplyViewModel.DocumentDraft(
                                data: data,
                                ext: "jpg",
                                fileName: "document_\(index + 1).jpg"
                            )
                        )
                    }
                }
                viewModel.setDocumentItems(drafts)
            }
        }
        .onChange(of: viewModel.didSubmit) { _, submitted in
            if submitted {
                dismiss()
            }
        }
        .alert("신청 오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        ), actions: {
            Button("확인") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }

    @ViewBuilder
    private var modeSpecificSection: some View {
        switch mode {
        case .partnerTaxi:
            Section("택시 정보") {
                TextField("자동차 번호", text: $viewModel.carNumber)
                TextField("메모", text: $viewModel.memo)
            }
        case .partnerDaeri:
            Section("대리 기사 정보") {
                TextField("메모", text: $viewModel.memo)
                Toggle("보험 가입됨", isOn: $viewModel.insuranceSubscribed)
            }
        case .partnerStore:
            Section("가게 정보") {
                Button(viewModel.selectedPlace == nil ? "가게 검색" : "가게 다시 선택") {
                    showPlaceSearch = true
                }
                if let place = viewModel.selectedPlace {
                    Text(place.name)
                    Text(place.address)
                        .foregroundStyle(.secondary)
                }
                Picker("카테고리", selection: $viewModel.storeCategory) {
                    Text("LIFE").tag("LIFE")
                    Text("FOOD").tag("FOOD")
                    Text("URGENT").tag("URGENT")
                }
            }
        case .general:
            EmptyView()
        }
    }
}
