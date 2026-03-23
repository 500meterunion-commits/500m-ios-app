import SwiftUI
import UIKit
import KakaoMapsSDK

struct KakaoMapContainerView: UIViewRepresentable {
    let center: LatLng?
    let radiusMeters: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let view = KMViewContainer()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.update(center: center, radiusMeters: radiusMeters)
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private weak var container: KMViewContainer?
        private var controller: KMController?
        private var kakaoMap: KakaoMap?
        private var labelLayer: LabelLayer?
        private var shapeLayer: ShapeLayer?
        private var userPoi: Poi?

        private var currentCenter: LatLng?
        private var currentRadiusMeters: Int = 500
        private var hasMovedCameraInitially = false
        private var lastCameraCenter: LatLng?
        private var lastCameraRadiusMeters: Int?

        private let viewName = "500m_map"
        private let labelLayerID = "user_marker_layer"
        private let shapeLayerID = "radius_shape_layer"
        private let poiStyleID = "user_location_style"
        private let polygonStyleID = "radius_polygon_style"
        private let userPoiID = "me"
        private let radiusShapeID = "radius"
        
        private var userMarkerImage: UIImage? {
            let baseImage: UIImage?
            if #available(iOS 17.0, *) {
                baseImage = UIImage(resource: .icMyRedDot)
            } else {
                baseImage = UIImage(named: "ic_my_red_dot", in: .main, compatibleWith: nil)
                ?? UIImage(named: "ic_my_red_dot")
                ?? UIImage(systemName: "location.fill")
            }

            guard let baseImage else { return nil }
            let targetSize = CGSize(
                width: max(4, baseImage.size.width / 10),
                height: max(4, baseImage.size.height / 10)
            )
            return resizedImage(baseImage, targetSize: targetSize)
        }

        func attach(to container: KMViewContainer) {
            guard self.container !== container else { return }
            self.container = container

            let controller = KMController(viewContainer: container)
            controller.delegate = self
            controller.prepareEngine()
            controller.activateEngine()
            self.controller = controller
        }

        func update(center: LatLng?, radiusMeters: Int) {
            currentCenter = center
            currentRadiusMeters = radiusMeters
            moveCameraIfNeeded()
            renderUserLocationAndRadius()
        }

        func addViews() {
            let defaultCenter = currentCenter ?? LatLng(lat: 35.1796, lng: 129.0756)
            let defaultPosition = MapPoint(longitude: defaultCenter.lng, latitude: defaultCenter.lat)
            let mapInfo = MapviewInfo(
                viewName: viewName,
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: zoomLevel(for: currentRadiusMeters)
            )
            controller?.addView(mapInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            kakaoMap = controller?.getView(viewName) as? KakaoMap
            configureLayersIfNeeded()
            configureStylesIfNeeded()
            moveCameraIfPossible(force: true)
            renderUserLocationAndRadius()
        }

        func containerDidResized(_ size: CGSize) { }

        private func configureLayersIfNeeded() {
            guard let map = kakaoMap else { return }

            if labelLayer == nil {
                let layerOptions = LabelLayerOptions(
                    layerID: labelLayerID,
                    competitionType: CompetitionType(rawValue: 0)!,
                    competitionUnit: CompetitionUnit(rawValue: 0)!,
                    orderType: OrderingType(rawValue: 0)!,
                    zOrder: 100
                )
                labelLayer = map.getLabelManager().addLabelLayer(option: layerOptions)
                labelLayer?.visible = true
            }

            if shapeLayer == nil {
                shapeLayer = map.getShapeManager().addShapeLayer(
                    layerID: shapeLayerID,
                    zOrder: 10,
                    passType: ShapeLayerPassType(rawValue: 1)!
                )
                shapeLayer?.visible = true
            }
        }

        private func configureStylesIfNeeded() {
            guard let map = kakaoMap else { return }

            if let userMarkerImage {
                let icon = PoiIconStyle(
                    symbol: userMarkerImage,
                    anchorPoint: CGPoint(x: 0.5, y: 0.5)
                )
                let style = PoiStyle(
                    styleID: poiStyleID,
                    styles: [PerLevelPoiStyle(iconStyle: icon, level: 0)]
                )
                map.getLabelManager().removePoiStyle(poiStyleID)
                map.getLabelManager().addPoiStyle(style)
            }

            let polygonStyle = PolygonStyle(
                styles: [
                    PerLevelPolygonStyle(
                        color: UIColor(red: 0.91, green: 0.29, blue: 0.29, alpha: 0.10),
                        strokeWidth: 2,
                        strokeColor: UIColor(red: 0.91, green: 0.29, blue: 0.29, alpha: 0.32),
                        level: 0
                    )
                ]
            )
            let styleSet = PolygonStyleSet(styleSetID: polygonStyleID, styles: [polygonStyle])
            map.getShapeManager().addPolygonStyleSet(styleSet)
        }

        private func renderUserLocationAndRadius() {
            guard let center = currentCenter else { return }
            guard let labelLayer, let shapeLayer else { return }

            let mapPoint = MapPoint(longitude: center.lng, latitude: center.lat)

            if let userPoi {
                userPoi.position = mapPoint
                userPoi.show()
            } else if userMarkerImage != nil {
                let option = PoiOptions(styleID: poiStyleID, poiID: userPoiID)
                option.rank = 1
                option.clickable = false
                userPoi = labelLayer.addPoi(option: option, at: mapPoint)
                userPoi?.show()
            }

            shapeLayer.removeMapPolygonShape(shapeID: radiusShapeID)

            let exteriorRing: [MapPoint] = Primitives.getCirclePoints(
                radius: Double(currentRadiusMeters),
                numPoints: 72,
                cw: true,
                center: mapPoint
            )
            let polygon = MapPolygon(exteriorRing: exteriorRing, holes: nil, styleIndex: UInt(0))
            let options = MapPolygonShapeOptions(shapeID: radiusShapeID, styleID: polygonStyleID, zOrder: 1)
            options.polygons = [polygon]
            let shape = shapeLayer.addMapPolygonShape(options)
            shape?.show()
        }

        private func moveCameraIfNeeded() {
            guard let center = currentCenter else { return }

            let needsCameraMove: Bool
            if !hasMovedCameraInitially {
                needsCameraMove = true
            } else if lastCameraRadiusMeters != currentRadiusMeters {
                needsCameraMove = true
            } else if let lastCameraCenter {
                let moved = GeoMath.haversineMeters(
                    center.lat,
                    center.lng,
                    lastCameraCenter.lat,
                    lastCameraCenter.lng
                )
                needsCameraMove = moved > 20
            } else {
                needsCameraMove = true
            }

            guard needsCameraMove else { return }
            moveCameraIfPossible(force: false)
        }

        private func moveCameraIfPossible(force: Bool) {
            guard let center = currentCenter, let kakaoMap else { return }

            let mapPoint = MapPoint(longitude: center.lng, latitude: center.lat)
            let update = CameraUpdate.make(
                target: mapPoint,
                zoomLevel: zoomLevel(for: currentRadiusMeters),
                mapView: kakaoMap
            )
            kakaoMap.moveCamera(update)
            hasMovedCameraInitially = true
            lastCameraCenter = center
            lastCameraRadiusMeters = currentRadiusMeters
        }

        private func zoomLevel(for radiusMeters: Int) -> Int {
            switch radiusMeters {
            case 100:
                return 18
            case 300:
                return 17
            default:
                return 16
            }
        }

        private func resizedImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}
