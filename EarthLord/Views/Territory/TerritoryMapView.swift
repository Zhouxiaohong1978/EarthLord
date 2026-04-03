//
//  TerritoryMapView.swift
//  EarthLord
//
//  编辑布局：点击选中建筑 → 单指拖拽移位 / 双指捏合缩放
//

import SwiftUI
import MapKit

struct TerritoryMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let templates: [String: BuildingTemplate]
    var showsUserLocation: Bool = true
    @Binding var isEditingLayout: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .excludingAll

        // 单指拖拽（移动选中建筑）
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        // 双指捏合（缩放选中建筑）
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        updateTerritoryPolygon(mapView)
        syncBuildingAnnotations(mapView)

        if !context.coordinator.hasInitializedRegion && !territoryCoordinates.isEmpty {
            let region = regionForCoordinates(territoryCoordinates)
            mapView.setRegion(region, animated: false)
            context.coordinator.hasInitializedRegion = true
            context.coordinator.boundaryCenter = region.center
            context.coordinator.boundarySpan = MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 0.1,
                longitudeDelta: region.span.longitudeDelta * 0.6
            )
        }

        // 退出编辑模式时清除选中状态
        if !isEditingLayout {
            context.coordinator.clearSelection(in: mapView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Private

    private func updateTerritoryPolygon(_ mapView: MKMapView) {
        let old = mapView.overlays.filter { ($0 as? MKPolygon)?.title == "territory" }
        mapView.removeOverlays(old)
        guard territoryCoordinates.count >= 3 else { return }
        let gcj = CoordinateConverter.wgs84ToGcj02(territoryCoordinates)
        let poly = MKPolygon(coordinates: gcj, count: gcj.count)
        poly.title = "territory"
        mapView.addOverlay(poly)
    }

    private func syncBuildingAnnotations(_ mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? TerritoryBuildingAnnotation }
        let existingIds = Set(existing.map { $0.building.id })
        let newIds = Set(buildings.map { $0.id })

        mapView.removeAnnotations(existing.filter { !newIds.contains($0.building.id) })

        for building in buildings where !existingIds.contains(building.id) {
            guard let coord = building.coordinate else { continue }
            let ann = TerritoryBuildingAnnotation(building: building)
            ann.coordinate = coord
            if let t = templates[building.templateId] {
                ann.title = "\(t.name) Lv.\(building.level)"
                ann.subtitle = t.category.displayName
                ann.template = t
            } else {
                ann.title = building.buildingName
            }
            mapView.addAnnotation(ann)
        }
    }

    private func regionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let gcj = CoordinateConverter.wgs84ToGcj02(coordinates)
        let lats = gcj.map { $0.latitude }
        let lons = gcj.map { $0.longitude }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lons.min()! + lons.max()!) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: (lats.max()! - lats.min()!) * 0.65,
                longitudeDelta: (lons.max()! - lons.min()!) * 0.65
            )
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: TerritoryMapView
        var hasInitializedRegion = false
        var boundaryCenter: CLLocationCoordinate2D?
        var boundarySpan: MKCoordinateSpan?

        private weak var selectedAnnotationView: MKAnnotationView?
        private var selectedAnnotation: TerritoryBuildingAnnotation?
        private var pinchStartSize: CGFloat = 44

        init(_ parent: TerritoryMapView) { self.parent = parent }

        // MARK: 选中清除

        func clearSelection(in mapView: MKMapView) {
            deselect(mapView: mapView)
        }

        private func deselect(mapView: MKMapView) {
            if let view = selectedAnnotationView {
                UIView.animate(withDuration: 0.2) {
                    view.transform = .identity
                    view.layer.shadowOpacity = 0
                }
            }
            selectedAnnotation = nil
            selectedAnnotationView = nil
            mapView.isScrollEnabled = true
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard parent.isEditingLayout else { return false }
            // pan 和 pinch 只有选中了建筑才开始
            return selectedAnnotation != nil
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // 捏合与平移可同时识别（但 pan 与地图 scroll 互斥，通过 isScrollEnabled 控制）
            return true
        }

        // MARK: 单指拖拽 → 移动建筑

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView,
                  let ann = selectedAnnotation else { return }

            let location = gesture.location(in: mapView)
            let newCoord = mapView.convert(location, toCoordinateFrom: mapView)
            ann.coordinate = newCoord

            // 同步移动 annotationView
            if let view = selectedAnnotationView {
                let pt = CGFloat(ann.building.mapDisplaySize ?? ann.template?.mapIconSize ?? 44)
                view.center = CGPoint(x: location.x, y: location.y - pt / 2)
            }

            if gesture.state == .ended || gesture.state == .cancelled {
                Task {
                    await BuildingManager.shared.updateBuildingPosition(
                        buildingId: ann.building.id,
                        lat: newCoord.latitude,
                        lon: newCoord.longitude
                    )
                }
            }
        }

        // MARK: 双指捏合 → 调整建筑图标尺寸

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView,
                  let ann = selectedAnnotation,
                  let view = selectedAnnotationView,
                  let template = ann.template,
                  !template.icon.contains("."),
                  let source = UIImage(named: template.icon) else { return }

            switch gesture.state {
            case .began:
                pinchStartSize = CGFloat(ann.building.mapDisplaySize ?? template.mapIconSize ?? 44)

            case .changed:
                let pt = max(24, min(200, pinchStartSize * gesture.scale))
                view.image = buildIcon(source: source, pt: pt)
                view.centerOffset = CGPoint(x: 0, y: -pt / 2)

            case .ended:
                let finalPt = Int(max(24, min(200, pinchStartSize * gesture.scale)))
                Task {
                    await BuildingManager.shared.updateBuildingDisplaySize(
                        buildingId: ann.building.id,
                        displaySize: finalPt
                    )
                }

            default: break
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard let center = boundaryCenter, let span = boundarySpan else { return }
            let cur = mapView.region.center
            let halfLat = span.latitudeDelta / 2
            let halfLon = span.longitudeDelta / 2
            let clampedLat = min(max(cur.latitude, center.latitude - halfLat), center.latitude + halfLat)
            let clampedLon = min(max(cur.longitude, center.longitude - halfLon), center.longitude + halfLon)
            guard abs(clampedLat - cur.latitude) > 0.000001 ||
                  abs(clampedLon - cur.longitude) > 0.000001 else { return }
            let clamped = CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
            mapView.setRegion(MKCoordinateRegion(center: clamped, span: mapView.region.span), animated: true)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                r.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                r.lineWidth = 3
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let ann = annotation as? TerritoryBuildingAnnotation else { return nil }

            let building = ann.building
            let template = ann.template
            let pt = CGFloat(building.mapDisplaySize ?? template?.mapIconSize ?? 44)

            if let template = template,
               building.status == .active,
               !template.icon.contains("."),
               let source = UIImage(named: template.icon) {

                let view = MKAnnotationView(annotation: ann, reuseIdentifier: "custom_\(building.id)")
                view.canShowCallout = !parent.isEditingLayout
                view.image = buildIcon(source: source, pt: pt)
                view.centerOffset = CGPoint(x: 0, y: -pt / 2)
                view.displayPriority = .required
                return view
            }

            let marker: MKMarkerAnnotationView
            if let d = mapView.dequeueReusableAnnotationView(withIdentifier: "marker") as? MKMarkerAnnotationView {
                marker = d; marker.annotation = ann
            } else {
                marker = MKMarkerAnnotationView(annotation: ann, reuseIdentifier: "marker")
            }
            marker.canShowCallout = !parent.isEditingLayout
            switch building.status {
            case .constructing, .upgrading:
                marker.markerTintColor = .systemOrange
                marker.glyphImage = UIImage(systemName: "hammer.fill")
            case .active:
                marker.markerTintColor = UIColor(template?.category.color ?? .green)
                marker.glyphImage = UIImage(systemName: template?.icon ?? "building.2.fill")
            case .inactive:
                marker.markerTintColor = .systemGray
                marker.glyphImage = UIImage(systemName: "pause.circle.fill")
            case .damaged:
                marker.markerTintColor = .systemRed
                marker.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
            }
            return marker
        }

        /// 点击建筑 → 在编辑模式下选中；普通模式下正常显示 callout
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard parent.isEditingLayout,
                  let ann = view.annotation as? TerritoryBuildingAnnotation else { return }

            // 先取消上一个选中
            deselect(mapView: mapView)

            selectedAnnotation = ann
            selectedAnnotationView = view

            // 高亮选中：放大 + 黄色光晕
            UIView.animate(withDuration: 0.2) {
                view.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                view.layer.shadowColor = UIColor.systemYellow.cgColor
                view.layer.shadowRadius = 10
                view.layer.shadowOpacity = 0.9
                view.layer.shadowOffset = .zero
            }

            // 锁定地图平移，让单指专门用于移动建筑
            mapView.isScrollEnabled = false

            // 阻止系统 callout 弹出
            mapView.deselectAnnotation(ann, animated: false)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            // 编辑模式下不走系统 deselect（我们自己管理）
        }

        // MARK: Helper

        private func buildIcon(source: UIImage, pt: CGFloat) -> UIImage {
            let size = CGSize(width: pt, height: pt)
            let rect = CGRect(origin: .zero, size: size)
            return UIGraphicsImageRenderer(size: size).image { _ in
                // 去除黑色背景：将 RGB 均 ≤50 的纯黑像素变为透明
                if let cg = source.cgImage,
                   (cg.alphaInfo == .none || cg.alphaInfo == .noneSkipFirst || cg.alphaInfo == .noneSkipLast),
                   let masked = cg.copy(maskingColorComponents: [0, 50, 0, 50, 0, 50]) {
                    UIImage(cgImage: masked).draw(in: rect)
                } else {
                    source.draw(in: rect)
                }
            }
        }
    }
}

// MARK: - TerritoryBuildingAnnotation

class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var template: BuildingTemplate?

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

// MARK: - Preview

#Preview {
    TerritoryMapView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        buildings: [],
        templates: [:],
        isEditingLayout: .constant(false)
    )
}
