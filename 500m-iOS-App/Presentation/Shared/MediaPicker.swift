import PhotosUI
import SwiftUI
import UIKit

enum MediaPickerSource: Identifiable {
    case camera
    case photoLibrary(selectionLimit: Int)

    var id: String {
        switch self {
        case .camera:
            return "camera"
        case let .photoLibrary(selectionLimit):
            return "photoLibrary-\(selectionLimit)"
        }
    }
}

struct MediaPicker: UIViewControllerRepresentable {
    let source: MediaPickerSource
    let onImagesPicked: ([UIImage]) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesPicked: onImagesPicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image"]
            picker.allowsEditing = false
            picker.modalPresentationStyle = .fullScreen
            picker.view.backgroundColor = .black
            return picker

        case let .photoLibrary(selectionLimit):
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = selectionLimit

            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            picker.modalPresentationStyle = .fullScreen
            picker.view.backgroundColor = .black
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        private let onImagesPicked: ([UIImage]) -> Void
        private let dismissAction: DismissAction

        init(onImagesPicked: @escaping ([UIImage]) -> Void, dismiss: DismissAction) {
            self.onImagesPicked = onImagesPicked
            self.dismissAction = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismissAction()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            if let image {
                onImagesPicked([image])
            }
            dismissAction()
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                dismissAction()
                return
            }

            let group = DispatchGroup()
            let lock = NSLock()
            var images: [UIImage] = []

            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else { return }
                    lock.lock()
                    images.append(image)
                    lock.unlock()
                }
            }

            group.notify(queue: .main) {
                if !images.isEmpty {
                    self.onImagesPicked(images)
                }
                self.dismissAction()
            }
        }
    }
}
