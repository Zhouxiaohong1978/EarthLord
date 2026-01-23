//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  建筑位置选择器 - 使用 UIKit MKMapView 显示领地多边形边界
//

import SwiftUI
import MapKit

/// 建筑位置选择器视图
struct BuildingLocationPickerView: View {
    /// 领地边界坐标（GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]
    /// 已有建筑列表
    let existingBuildings: [PlayerBuilding]
    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]
    /// 选择位置回调
    var onSelectLocation: (CLLocationCoordinate2D) -> Void
    /// 取消回调
    var onCancel: () -> Void

    /// 选中的位置
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    /// 是否显示位置无效提示
    @State private var showInvalidLocationAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                // 地图视图
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $selectedCoordinate,
                    onInvalidLocation: {
                        showInvalidLocationAlert = true
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 底部操作栏
                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .navigationTitle(String(localized: "选择建造位置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "取消")) {
                        onCancel()
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
            .alert(String(localized: "位置无效"), isPresented: $showInvalidLocationAlert) {
                Button(String(localized: "知道了"), role: .cancel) {}
            } message: {
                Text(String(localized: "请在领地范围内选择建造位置"))
            }
        }
    }

    /// 底部操作栏
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 提示文字
            if selectedCoordinate == nil {
                Text(String(localized: "点击地图选择建造位置"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text(String(localized: "已选择位置"))
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 确认按钮
            Button {
                if let coord = selectedCoordinate {
                    onSelectLocation(coord)
                }
            } label: {
                Text(String(localized: "确认位置"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedCoordinate != nil ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    )
            }
            .disabled(selectedCoordinate == nil)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - UIKit 地图视图

/// 位置选择器地图视图（UIKit）
struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var onInvalidLocation: () -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid  // 卫星混合模式
        mapView.showsUserLocation = true

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 设置地图区域为领地范围
            let region = regionForPolygon(territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        // 添加已有建筑标记
        context.coordinator.addExistingBuildings(to: mapView)

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标记
        context.coordinator.updateSelectedAnnotation(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 计算多边形的显示区域
    private func regionForPolygon(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        private var selectedAnnotation: MKPointAnnotation?

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        /// 添加已有建筑标记
        func addExistingBuildings(to mapView: MKMapView) {
            for building in parent.existingBuildings {
                guard let coord = building.coordinate else { continue }

                // 数据库中的坐标已经是 GCJ-02，直接使用
                let annotation = ExistingBuildingAnnotation(building: building)
                annotation.coordinate = coord
                annotation.title = building.buildingName

                if let template = parent.buildingTemplates[building.templateId] {
                    annotation.subtitle = "Lv.\(building.level) · \(template.category.displayName)"
                }

                mapView.addAnnotation(annotation)
            }
        }

        /// 更新选中位置标记
        func updateSelectedAnnotation(on mapView: MKMapView) {
            // 移除旧的选中标记
            if let old = selectedAnnotation {
                mapView.removeAnnotation(old)
            }

            // 添加新的选中标记
            if let coord = parent.selectedCoordinate {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coord
                annotation.title = String(localized: "建造位置")
                mapView.addAnnotation(annotation)
                selectedAnnotation = annotation
            }
        }

        /// 处理点击手势
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查点是否在领地多边形内
            if isPointInPolygon(coordinate, polygon: parent.territoryCoordinates) {
                parent.selectedCoordinate = coordinate
            } else {
                parent.onInvalidLocation()
            }
        }

        /// 点在多边形内算法（射线法）
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }

            return isInside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            if annotation is MKUserLocation {
                return nil
            }

            // 已有建筑标记
            if let buildingAnnotation = annotation as? ExistingBuildingAnnotation {
                let identifier = "ExistingBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = buildingAnnotation
                }

                // 设置已有建筑的样式
                annotationView?.markerTintColor = .systemGray
                annotationView?.glyphImage = UIImage(systemName: "building.2.fill")

                return annotationView
            }

            // 选中位置标记
            let identifier = "SelectedLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 设置选中位置的样式
            annotationView?.markerTintColor = UIColor(ApocalypseTheme.primary)
            annotationView?.glyphImage = UIImage(systemName: "hammer.fill")

            return annotationView
        }
    }
}

// MARK: - 自定义标注

/// 已有建筑标注
class ExistingBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

// MARK: - Color Extension for UIKit

extension Color {
    /// 转换为 UIColor
    func toUIColor() -> UIColor {
        UIColor(self)
    }
}

extension UIColor {
    /// 从 SwiftUI Color 创建
    convenience init(_ color: Color) {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        self.init(
            red: components[0],
            green: components.count > 1 ? components[1] : components[0],
            blue: components.count > 2 ? components[2] : components[0],
            alpha: components.count > 3 ? components[3] : 1.0
        )
    }
}

// MARK: - ApocalypseTheme UIColor Extension

extension ApocalypseTheme {
    /// 成功色的 UIColor 版本
    static var successUIColor: UIColor {
        UIColor(success)
    }

    /// 主色的 UIColor 版本
    static var primaryUIColor: UIColor {
        UIColor(primary)
    }
}

// MARK: - Preview

#Preview {
    BuildingLocationPickerView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        existingBuildings: [],
        buildingTemplates: [:],
        onSelectLocation: { coord in
            print("选择位置: \(coord)")
        },
        onCancel: {}
    )
}
