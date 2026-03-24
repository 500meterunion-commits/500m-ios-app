import SwiftUI
import UIKit

struct PartnerApplyView: View {
    private enum Step {
        case info
        case docs
    }

    let mode: UserMode

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PartnerApplyViewModel
    @State private var showPlaceSearch = false
    @State private var showTerms = false
    @State private var didCheckTerms = false
    @State private var step: Step = .info
    @State private var showDocumentSourceDialog = false
    @State private var activeMediaPicker: MediaPickerSource?
    @State private var showCameraUnavailableAlert = false

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)

    init(mode: UserMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: PartnerApplyViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch step {
            case .info:
                infoScreen
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .docs:
                docsScreen
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.24), value: step)
        .task {
            viewModel.configure(container: container)
            if !didCheckTerms {
                didCheckTerms = true
                try? await Task.sleep(for: .milliseconds(150))
                if !viewModel.agreePartnerTerms {
                    showTerms = true
                }
            }
        }
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchSheet { place in
                viewModel.selectedPlace = place
            }
            .environmentObject(container)
        }
        .fullScreenCover(isPresented: $showTerms) {
            PartnerTermsAgreementView(
                onBack: { dismiss() },
                onAgree: { checkedMap in
                    viewModel.agreePartnerTerms = checkedMap["terms_service"] == true && checkedMap["terms_location"] == true
                    showTerms = false
                }
            )
        }
        .confirmationDialog("서류 이미지를 선택해 주세요", isPresented: $showDocumentSourceDialog, titleVisibility: .visible) {
            Button("앨범에서 선택") {
                let remaining = max(1, 5 - viewModel.documents.count)
                activeMediaPicker = .photoLibrary(selectionLimit: remaining)
            }
            Button("직접 촬영") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    activeMediaPicker = .camera
                } else {
                    showCameraUnavailableAlert = true
                }
            }
            Button("취소", role: .cancel) {}
        }
        .fullScreenCover(item: $activeMediaPicker) { source in
            ZStack {
                Color.black.ignoresSafeArea()
                MediaPicker(source: source) { images in
                    applyPickedDocuments(images)
                }
            }
            .ignoresSafeArea()
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
        )) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("카메라를 사용할 수 없습니다", isPresented: $showCameraUnavailableAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("현재 기기에서는 카메라 촬영을 사용할 수 없어 앨범 선택만 가능합니다.")
        }
    }

    private var infoScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Spacer().frame(height: 28)
                    Text(titleText)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

                    fieldBlock("이름", text: $viewModel.name, placeholder: "이름을 입력하세요")
                    fieldBlock("생년월일", text: $viewModel.birthDate, placeholder: "예: 1990-01-01")
                    fieldBlock("연락처", text: $viewModel.contact, placeholder: "연락처를 입력하세요")
                    marketSection
                    modeSpecificInfoSection
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }

            bottomButtons(
                leftTitle: "취소",
                rightTitle: "다음",
                rightEnabled: canGoNext,
                onLeft: { dismiss() },
                onRight: { step = .docs }
            )
        }
    }

    private var docsScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer().frame(height: 20)
                    Text("인증서류 제출")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                    Text(documentGuideText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 0.6, green: 0.65, blue: 0.71))

                    Button {
                        showDocumentSourceDialog = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "camera")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(red: 0.8, green: 0.82, blue: 0.86))
                            Text("서류 이미지를 첨부해주세요")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.6, green: 0.65, blue: 0.71))
                            Text("이미지 선택하기")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .frame(height: 56)
                                .background(Color(red: 0.92, green: 0.51, blue: 0.51), in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color(red: 0.86, green: 0.89, blue: 0.93), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(Array(viewModel.documents.enumerated()), id: \.element.id) { index, document in
                            ZStack(alignment: .topTrailing) {
                                Rectangle()
                                    .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                    .overlay {
                                        Image(uiImage: UIImage(data: document.data) ?? UIImage())
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color(red: 0.86, green: 0.89, blue: 0.93), lineWidth: 1)
                                    )

                                Button {
                                    var updated = viewModel.documents
                                    updated.remove(at: index)
                                    viewModel.setDocumentItems(updated)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white, in: Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                                }
                                .padding(10)
                            }
                        }
                    }

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }

            bottomButtons(
                leftTitle: "이전",
                rightTitle: viewModel.isSubmitting ? "제출중..." : "제출",
                rightEnabled: !viewModel.isSubmitting && !viewModel.documents.isEmpty && viewModel.canSubmit,
                onLeft: { step = .info },
                onRight: { viewModel.submit() }
            )
        }
    }

    private func fieldBlock(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
            TextField(placeholder, text: text)
                .font(.system(size: 19, weight: .medium))
                .padding(.horizontal, 20)
                .frame(height: 86)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(red: 0.63, green: 0.67, blue: 0.71), lineWidth: 1.5)
                )
        }
    }

    private var marketSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .partnerStore ? "지역" : "활동 지역")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            HStack(spacing: 18) {
                pillButton("부산", selected: viewModel.marketID == "busan") { viewModel.marketID = "busan" }
                pillButton("울산", selected: viewModel.marketID == "ulsan") { viewModel.marketID = "ulsan" }
            }
        }
    }

    @ViewBuilder
    private var modeSpecificInfoSection: some View {
        switch mode {
        case .partnerTaxi:
            fieldBlock("자동차 번호", text: $viewModel.carNumber, placeholder: "예: 12가3456")
            memoSection
        case .partnerDaeri:
            insuranceSection
            memoSection
        case .partnerStore:
            storeCategorySection
            storePickerSection
        case .general:
            EmptyView()
        }
    }

    private var insuranceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("보험 가입 여부")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
            HStack(spacing: 18) {
                pillButton("보험 가입", selected: viewModel.insuranceSubscribed) { viewModel.insuranceSubscribed = true }
                pillButton("보험 미가입", selected: !viewModel.insuranceSubscribed) { viewModel.insuranceSubscribed = false }
            }
        }
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메모")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
            TextField("메모 입력", text: $viewModel.memo, axis: .vertical)
                .font(.system(size: 19, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(minHeight: 160, alignment: .topLeading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(red: 0.63, green: 0.67, blue: 0.71), lineWidth: 1.5)
                )
        }
    }

    private var storeCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            HStack(spacing: 16) {
                categoryButton("생활밀착", asset: "ic_life", selected: viewModel.storeCategory == "LIFE") {
                    viewModel.storeCategory = "LIFE"
                }
                categoryButton("음식", asset: "ic_food", selected: viewModel.storeCategory == "FOOD") {
                    viewModel.storeCategory = "FOOD"
                }
            }
            categoryButton("긴급 전문", asset: "ic_urgent", selected: viewModel.storeCategory == "URGENT") {
                viewModel.storeCategory = "URGENT"
            }
        }
    }

    private var storePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("가게 선택")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.selectedPlace.map { "\($0.name) (\($0.id))" } ?? "선택된 가게 없음")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.26, blue: 0.33))

                HStack(spacing: 12) {
                    Button("가게 검색") {
                        showPlaceSearch = true
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.63, green: 0.67, blue: 0.71), lineWidth: 1.3)
                    )

                    if viewModel.selectedPlace != nil {
                        Button("선택 해제") {
                            viewModel.selectedPlace = nil
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brandRed)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func pillButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(selected ? .white : Color(red: 0.14, green: 0.2, blue: 0.28))
                .padding(.horizontal, 28)
                .frame(height: 68)
                .background(
                    RoundedRectangle(cornerRadius: 34)
                        .fill(selected ? Color(red: 0.92, green: 0.51, blue: 0.51) : .white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(selected ? Color.clear : Color(red: 0.87, green: 0.9, blue: 0.94), lineWidth: 1.5)
                )
                .shadow(color: selected ? Color.black.opacity(0.08) : .clear, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func categoryButton(_ title: String, asset: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Color(red: 0.14, green: 0.2, blue: 0.28))
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Color(red: 0.92, green: 0.51, blue: 0.51) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.clear : Color(red: 0.87, green: 0.9, blue: 0.94), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func bottomButtons(
        leftTitle: String,
        rightTitle: String,
        rightEnabled: Bool,
        onLeft: @escaping () -> Void,
        onRight: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Button(action: onLeft) {
                Text(leftTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.93, green: 0.54, blue: 0.56))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.95, green: 0.61, blue: 0.63), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onRight) {
                Text(rightTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(rightEnabled ? brandRed : Color(red: 0.9, green: 0.9, blue: 0.91))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!rightEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(Color.white)
    }

    private var titleText: String {
        switch mode {
        case .partnerTaxi: return "택시 기사 신청"
        case .partnerDaeri: return "대리 기사 신청"
        case .partnerStore: return "가게 파트너 신청"
        case .general: return "파트너 신청"
        }
    }

    private var documentGuideText: String {
        switch mode {
        case .partnerTaxi:
            return "택시운전자격증, 운전면허증을 제출해 주세요"
        case .partnerStore:
            return "사업자등록증을 제출해 주세요"
        case .partnerDaeri:
            return "운전면허증(필수), 보험가입완료 서류(미가입 시 제출 불필요)"
        case .general:
            return "서류를 최소 1장 이상 첨부해 주세요"
        }
    }

    private var canGoNext: Bool {
        if viewModel.name.nilIfBlank == nil { return false }
        if viewModel.birthDate.nilIfBlank == nil { return false }
        if viewModel.contact.nilIfBlank == nil { return false }

        switch mode {
        case .partnerTaxi:
            return viewModel.carNumber.nilIfBlank != nil && viewModel.memo.nilIfBlank != nil
        case .partnerDaeri:
            return viewModel.memo.nilIfBlank != nil
        case .partnerStore:
            return viewModel.selectedPlace != nil
        case .general:
            return false
        }
    }

    private func applyPickedDocuments(_ images: [UIImage]) {
        guard !images.isEmpty else { return }

        var updated = viewModel.documents
        let startIndex = updated.count

        for (offset, image) in images.enumerated() {
            guard updated.count < 5 else { break }
            guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
            updated.append(
                PartnerApplyViewModel.DocumentDraft(
                    data: data,
                    ext: "jpg",
                    fileName: "document_\(startIndex + offset + 1).jpg"
                )
            )
        }

        viewModel.setDocumentItems(updated)
    }
}
