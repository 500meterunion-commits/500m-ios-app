import SwiftUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EditProfileViewModel()
    @State private var imageData: Data?
    @State private var showImageSourceDialog = false
    @State private var activeMediaPicker: MediaPickerSource?
    @State private var showCameraUnavailableAlert = false

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer().frame(height: 18)

                    profileImagePicker

                    fieldBlock(
                        title: "이름",
                        borderColor: brandRed,
                        content: AnyView(
                            TextField("", text: $viewModel.name)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                        )
                    )

                    if viewModel.mode == .partnerTaxi || viewModel.mode == .partnerDaeri {
                        fieldBlock(
                            title: "상태 메시지 (선택)",
                            borderColor: Color(red: 0.88, green: 0.9, blue: 0.94),
                            content: AnyView(
                                TextField("예: 오늘도 안전 운행 하세요!", text: $viewModel.memo)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                            )
                        )
                    } else {
                        fieldBlock(
                            title: "계정 등급",
                            borderColor: .clear,
                            background: Color(red: 0.96, green: 0.97, blue: 0.98),
                            content: AnyView(
                                Text(accountGradeText)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color(red: 0.67, green: 0.73, blue: 0.79))
                            )
                        )
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }

            saveButton
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.configure(container: container)
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
                dismiss()
            }
        }
        .confirmationDialog("프로필 이미지를 선택해 주세요", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
            Button("앨범에서 선택") {
                activeMediaPicker = .photoLibrary(selectionLimit: 1)
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
                    guard let image = images.first else { return }
                    imageData = image.jpegData(compressionQuality: 0.9)
                }
            }
            .ignoresSafeArea()
        }
        .alert("저장 오류", isPresented: Binding(
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

    private var header: some View {
        ZStack {
            Text("프로필 수정")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var profileImagePicker: some View {
        HStack {
            Spacer()
            Button {
                showImageSourceDialog = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatar(size: 132)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.41, green: 0.47, blue: 0.55))
                        }
                        .offset(x: -10, y: -5)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 26)
        .padding(.bottom, 8)
    }

    private func fieldBlock(
        title: String,
        borderColor: Color,
        background: Color = .white,
        content: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.25, green: 0.31, blue: 0.39))

            content
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 56)
                .background(background, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 2)
                )
        }
    }

    private var saveButton: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0)

            Button {
                viewModel.save(imageData: imageData)
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("저장하기")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(brandRed)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(Color.white)
        }
    }

    @ViewBuilder
    private func avatar(size: CGFloat) -> some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let urlString = viewModel.remoteImageURL?.nilIfBlank, let url = URL(string: urlString) {
            CachedRemoteImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                fallbackAvatar(size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar(size: size)
        }
    }

    private func fallbackAvatar(size: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.51, green: 0.35, blue: 0.78))
            .frame(width: size, height: size)
            .overlay {
                Text(initialLetter)
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(.white)
            }
    }

    private var initialLetter: String {
        let raw = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "A" : String(raw.prefix(1)).uppercased()
    }

    private var accountGradeText: String {
        switch viewModel.mode {
        case .general:
            return "일반 사용자"
        case .partnerStore:
            return "자영업 파트너"
        case .partnerTaxi:
            return "택시 기사"
        case .partnerDaeri:
            return "대리 기사"
        }
    }
}
