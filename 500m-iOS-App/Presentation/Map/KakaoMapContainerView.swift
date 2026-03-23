import SwiftUI
import UIKit
import KakaoMapsSDK

struct KakaoMapContainerView: UIViewRepresentable {
    let center: LatLng?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let view = KMViewContainer()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.updateCenter(center)
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private weak var container: KMViewContainer?
        private var controller: KMController?
        private var kakaoMap: KakaoMap?
        private var currentCenter: LatLng?
        private let viewName = "500m_map"

        func attach(to container: KMViewContainer) {
            guard self.container !== container else { return }
            self.container = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            controller.prepareEngine()
            controller.activateEngine()
            self.controller = controller
        }

        func updateCenter(_ center: LatLng?) {
            currentCenter = center
            moveCameraIfPossible()
        }

        func addViews() {
            let defaultCenter = currentCenter ?? LatLng(lat: 35.1796, lng: 129.0756)
            let defaultPosition = MapPoint(longitude: defaultCenter.lng, latitude: defaultCenter.lat)
            let mapInfo = MapviewInfo(
                viewName: viewName,
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: 17
            )
            controller?.addView(mapInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            kakaoMap = controller?.getView(viewName) as? KakaoMap
            moveCameraIfPossible()
        }

        func containerDidResized(_ size: CGSize) { }

        private func moveCameraIfPossible() {
            guard let center = currentCenter, let kakaoMap else { return }
            let mapPoint = MapPoint(longitude: center.lng, latitude: center.lat)
            let update = CameraUpdate.make(target: mapPoint, zoomLevel: 17, mapView: kakaoMap)
            kakaoMap.moveCamera(update)
        }
    }
}
