import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EditProfileViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        Form {
            Section("프로필 사진") {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HStack {
                        Text(imageData == nil ? "사진 선택" : "사진 변경")
                        Spacer()
                        Image(systemName: "photo")
                    }
                }
            }

            Section("기본 정보") {
                TextField("이름", text: $viewModel.name)
                if viewModel.mode == .partnerTaxi || viewModel.mode == .partnerDaeri {
                    TextField("상태 메시지", text: $viewModel.memo)
                }
            }

            Section {
                Button("저장하기") {
                    viewModel.save(imageData: imageData)
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("프로필 수정")
        .task {
            viewModel.configure(container: container)
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                imageData = try? await newItem.loadTransferable(type: Data.self)
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
                dismiss()
            }
        }
        .alert("저장 오류", isPresented: Binding(
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
}
