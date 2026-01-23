//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图组件（UIKit）- 全屏显示领地多边形和建筑标记
//

import SwiftUI
import MapKit

/// 领地地图视图（全屏）
struct TerritoryMapView: UIViewRepresentable {
    /// 领地边界坐标（原始 WGS-84，会自动转换为 GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]
    /// 领地内的建筑列表
    let buildings: [PlayerBuilding]
    /// 建筑模板字典
    let templates: [String: BuildingTemplate]
    /// 是否显示用户位置
    var showsUserLocation: Bool = true

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid  // 卫星混合模式
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = true
        mapView.showsScale = true

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新领地多边形
        updateTerritoryPolygon(mapView, context: context)

        // 更新建筑标记
        updateBuildingAnnotations(mapView, context: context)

        // 首次加载时设置地图区域
        if !context.coordinator.hasInitializedRegion && !territoryCoordinates.isEmpty {
            let region = regionForCoordinates(territoryCoordinates)
            mapView.setRegion(region, animated: false)
            context.coordinator.hasInitializedRegion = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 更新领地多边形
    private func updateTerritoryPolygon(_ mapView: MKMapView, context: Context) {
        // 移除旧的领地多边形
        let territoryOverlays = mapView.overlays.filter { ($0 as? MKPolygon)?.title == "territory" }
        mapView.removeOverlays(territoryOverlays)

        // 添加新的领地多边形
        guard territoryCoordinates.count >= 3 else { return }

        // 坐标转换（WGS-84 → GCJ-02）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(territoryCoordinates)

        let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon)
    }

    /// 更新建筑标记
    private func updateBuildingAnnotations(_ mapView: MKMapView, context: Context) {
        // 移除旧的建筑标记
        let buildingAnnotations = mapView.annotations.compactMap { $0 as? TerritoryBuildingAnnotation }
        mapView.removeAnnotations(buildingAnnotations)

        // 添加新的建筑标记
        for building in buildings {
            guard let coord = building.coordinate else { continue }

            // 注意：数据库中保存的已经是 GCJ-02 坐标，直接使用无需转换
            let annotation = TerritoryBuildingAnnotation(building: building)
            annotation.coordinate = coord

            if let template = templates[building.templateId] {
                annotation.title = "\(building.buildingName) Lv.\(building.level)"
                annotation.subtitle = template.category.displayName
                annotation.template = template
            } else {
                annotation.title = building.buildingName
            }

            mapView.addAnnotation(annotation)
        }
    }

    /// 计算坐标的显示区域
    private func regionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        // 坐标转换（WGS-84 → GCJ-02）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

        let lats = gcj02Coordinates.map { $0.latitude }
        let lons = gcj02Coordinates.map { $0.longitude }

        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // 添加一些边距
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.001,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.001
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView
        var hasInitializedRegion = false

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标记
            if let buildingAnnotation = annotation as? TerritoryBuildingAnnotation {
                let identifier = "TerritoryBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = buildingAnnotation
                }

                // 根据建筑状态设置样式
                let building = buildingAnnotation.building

                switch building.status {
                case .constructing, .upgrading:
                    annotationView?.markerTintColor = .systemOrange
                    annotationView?.glyphImage = UIImage(systemName: "hammer.fill")
                case .active:
                    if let template = buildingAnnotation.template {
                        annotationView?.markerTintColor = UIColor(template.category.color)
                        annotationView?.glyphImage = UIImage(systemName: template.icon)
                    } else {
                        annotationView?.markerTintColor = .systemGreen
                        annotationView?.glyphImage = UIImage(systemName: "building.2.fill")
                    }
                case .inactive:
                    annotationView?.markerTintColor = .systemGray
                    annotationView?.glyphImage = UIImage(systemName: "pause.circle.fill")
                case .damaged:
                    annotationView?.markerTintColor = .systemRed
                    annotationView?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                }

                return annotationView
            }

            return nil
        }
    }
}

// MARK: - 建筑标注

/// 领地建筑标注
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
        templates: [:]
    )
}
