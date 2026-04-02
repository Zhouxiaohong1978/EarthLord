//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 实现末世风格地图
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable

/// 将 MKMapView 包装为 SwiftUI 视图
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位居中
    @Binding var hasLocatedUser: Bool

    /// 追踪路径坐标（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    // MARK: - Properties

    /// 路径更新版本号（用于触发刷新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分我的领地和他人领地）
    var currentUserId: String?

    // MARK: - 探索轨迹属性

    /// 探索路径坐标
    var explorationPath: [CLLocationCoordinate2D]

    /// 探索路径版本号
    var explorationPathVersion: Int

    /// 是否正在探索
    var isExploring: Bool

    /// 附近的POI列表
    var nearbyPOIs: [POI] = []

    /// 冷却中的POI坐标Key集合（用于地图标记变灰）
    var coolingDownPOIKeys: Set<String> = []

    // MARK: - 建筑显示属性

    /// 玩家建筑列表
    var buildings: [PlayerBuilding] = []

    /// 建筑模板列表
    var buildingTemplates: [BuildingTemplate] = []

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // MARK: 地图类型配置
        mapView.mapType = .hybrid  // 卫星图 + 道路标签（末世废土风格）

        // MARK: 隐藏默认 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏3D建筑
        mapView.showsBuildings = false

        // MARK: 显示用户位置蓝点（关键！这会触发 MapKit 开始获取位置）
        mapView.showsUserLocation = true

        // MARK: 交互设置
        mapView.isZoomEnabled = true   // 允许双指缩放
        mapView.isScrollEnabled = true  // 允许单指拖动
        mapView.isRotateEnabled = true  // 允许旋转
        mapView.isPitchEnabled = true   // 允许倾斜

        // 显示指南针
        mapView.showsCompass = true

        // MARK: 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // MARK: 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 设置默认区域（中国中心位置，作为初始视图）
        let defaultCenter = CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0)
        let defaultRegion = MKCoordinateRegion(
            center: defaultCenter,
            latitudinalMeters: 5000000,  // 约5000公里范围
            longitudinalMeters: 5000000
        )
        mapView.setRegion(defaultRegion, animated: false)

        return mapView
    }

    /// 更新视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 同步最新数据到 Coordinator（确保 viewForAnnotation 能读到最新的 coolingDownPOIKeys）
        context.coordinator.parent = self

        // 更新圈地轨迹显示
        updateTrackingPath(on: uiView, context: context)

        // 更新探索轨迹显示
        updateExplorationPath(on: uiView, context: context)

        // 绘制领地
        drawTerritories(on: uiView, context: context)

        // 更新POI标记
        updatePOIAnnotations(on: uiView, context: context)

        // 更新建筑标记
        updateBuildingAnnotations(on: uiView, context: context)
    }

    /// 创建 Coordinator 代理
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 轨迹更新

    /// 更新轨迹路径显示
    private func updateTrackingPath(on mapView: MKMapView, context: Context) {
        // 检查版本号是否变化（避免重复更新）
        guard context.coordinator.lastPathVersion != pathUpdateVersion else { return }
        context.coordinator.lastPathVersion = pathUpdateVersion

        // 移除旧的追踪覆盖层（保留领地多边形和探索轨迹）
        let trackingOverlays = mapView.overlays.filter { overlay in
            // 保留领地多边形（有 title 为 "mine" 或 "others"）
            if let polygon = overlay as? MKPolygon {
                return polygon.title != "mine" && polygon.title != "others"
            }
            // 只移除圈地轨迹线，保留探索轨迹线（title == "exploration"）
            if let polyline = overlay as? MKPolyline {
                return polyline.title != "exploration"
            }
            return false
        }
        mapView.removeOverlays(trackingOverlays)

        // 如果路径少于2个点，不需要绘制
        guard trackingPath.count >= 2 else { return }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标
        // GPS 返回 WGS-84 坐标，高德底图使用 GCJ-02 坐标系
        let convertedCoordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)
        polyline.title = "tracking"
        mapView.addOverlay(polyline)

        // 如果已闭环且点数 ≥ 3，添加多边形填充
        if isPathClosed && convertedCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: convertedCoordinates, count: convertedCoordinates.count)
            polygon.title = "tracking"  // 标记为追踪多边形
            mapView.addOverlay(polygon)
            print("🗺️ 更新轨迹显示: \(trackingPath.count) 个点（已闭环，添加多边形）")
        } else {
            print("🗺️ 更新轨迹显示: \(trackingPath.count) 个点")
        }
    }

    // MARK: - 探索轨迹绘制

    /// 更新探索轨迹显示
    private func updateExplorationPath(on mapView: MKMapView, context: Context) {
        // 检查版本号是否变化
        guard context.coordinator.lastExplorationPathVersion != explorationPathVersion else { return }
        context.coordinator.lastExplorationPathVersion = explorationPathVersion

        // 移除旧的探索轨迹
        let explorationOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                return polyline.title == "exploration"
            }
            return false
        }
        mapView.removeOverlays(explorationOverlays)

        // 如果不在探索或路径少于2个点，不绘制
        guard isExploring && explorationPath.count >= 2 else { return }

        // 将 WGS-84 坐标转换为 GCJ-02
        let convertedCoordinates = CoordinateConverter.wgs84ToGcj02(explorationPath)

        // 创建探索轨迹线
        let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)
        polyline.title = "exploration"
        mapView.addOverlay(polyline)

        print("🚶 更新探索轨迹: \(explorationPath.count) 个点")
    }

    // MARK: - 领地绘制

    /// 测试领地名称前缀
    private static let testTerritoryPrefix = "[TEST]"

    /// 绘制领地多边形
    private func drawTerritories(on mapView: MKMapView, context: Context) {
        // 检查领地数量是否变化
        let currentCount = territories.count
        guard context.coordinator.lastTerritoriesCount != currentCount else { return }
        context.coordinator.lastTerritoriesCount = currentCount

        // 移除旧的领地多边形（保留轨迹）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // ⚠️ 中国大陆需要坐标转换（WGS-84 → GCJ-02）
            // GPS 返回 WGS-84 坐标，高德底图使用 GCJ-02 坐标系
            coords = CoordinateConverter.wgs84ToGcj02(coords)

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：使用 AuthManager 检查是否为关联账号的领地
            // 这样可以正确识别所有关联账号拥有的领地
            let isMine = AuthManager.shared.isLinkedUser(territory.userId)

            // ⭐ 特殊处理：名称带 [TEST] 前缀的领地显示为"他人领地"（橙色）
            // 这样可以用于测试碰撞检测等功能
            let isTestTerritory = territory.name?.hasPrefix(Self.testTerritoryPrefix) ?? false

            // 如果是测试领地，即使是自己的也显示为橙色（模拟他人领地）
            polygon.title = (isMine && !isTestTerritory) ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        if currentCount > 0 {
            print("🗺️ 绘制了 \(currentCount) 个领地")
        }
    }

    // MARK: - 末世滤镜效果

    /// 应用末世风格的滤镜效果
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 创建滤镜数组
        var filters: [Any] = []

        // 色调控制：降低饱和度和亮度
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
            colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度
            filters.append(colorControls)
        }

        // 棕褐色调：废土的泛黄效果
        if let sepiaFilter = CIFilter(name: "CISepiaTone") {
            sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)  // 泛黄强度
            filters.append(sepiaFilter)
        }

        // 应用滤镜到地图图层
        mapView.layer.filters = filters
    }

    // MARK: - Coordinator

    /// 处理 MKMapView 代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 首次居中标志 - 防止重复居中
        private var hasInitialCentered = false

        /// 上次路径版本号 - 避免重复更新
        var lastPathVersion: Int = -1

        /// 上次探索轨迹版本号
        var lastExplorationPathVersion: Int = -1

        /// 上次领地数量 - 避免重复绘制
        var lastTerritoriesCount: Int = -1

        /// 上次建筑哈希（ID+坐标）- 检测数量和位置变化
        var lastBuildingsHash: String = ""

        /// 上次地图缩放级别 - 用于动态调整图标尺寸
        var lastRegionLatDelta: CLLocationDegrees = -1

        /// 上次POI数量 - 避免重复更新
        var lastPOICount: Int = -1

        /// 上次已搜刮POI数量 - 避免重复更新
        var lastScavengedCount: Int = -1

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: ⭐ 关键方法：用户位置更新时调用

        /// 当用户位置更新时触发
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置坐标
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        // MARK: ⭐ 关键方法：轨迹渲染器（必须实现！否则轨迹看不见）

        /// 为覆盖层提供渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据轨迹类型设置颜色
                if polyline.title == "exploration" {
                    // 🚶 探索轨迹：亮青蓝色虚线，区别于橙色领地
                    renderer.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.95)
                    renderer.lineWidth = 4.0
                    renderer.lineDashPattern = [10, 6]
                } else {
                    // 🗺️ 圈地轨迹：闭环后从青色变成绿色
                    if parent.isPathClosed {
                        renderer.strokeColor = UIColor.systemGreen
                    } else {
                        renderer.strokeColor = UIColor.systemCyan
                    }
                    renderer.lineWidth = 4.0
                }

                renderer.lineCap = .round
                renderer.lineJoin = .round

                return renderer
            }

            // 处理多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分多边形类型
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 追踪多边形（闭环时的填充）：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2.0

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: ⭐ 关键方法：自定义 POI 标注视图

        /// 为标注提供自定义视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 不自定义用户位置蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // 处理建筑标注
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                // 优先用 annotation 上绑定的模板，若为 nil 则从当前模板列表中回查（防止加载时序问题）
                let template = buildingAnnotation.template
                    ?? parent.buildingTemplates.first { $0.templateId == buildingAnnotation.building.templateId }
                let iconName = template?.icon ?? "building.2.fill"
                let isCustomIcon = !iconName.contains(".")

                if isCustomIcon {
                    // 自定义图片：渲染成圆形 UIImage 直接作为标注图标
                    let identifier = "BuildingCustomMarker"
                    let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                    annotationView.annotation = annotation
                    annotationView.canShowCallout = true

                    if let source = UIImage(named: iconName) {
                        let latDelta = mapView.region.span.latitudeDelta
                        let referenceSpan: CLLocationDegrees = 0.005
                        let scaleFactor = CGFloat(min(max(referenceSpan / latDelta, 0.25), 3.0))
                        let baseSize = CGFloat(template?.mapIconSize ?? 60)
                        let iconSize = (baseSize * scaleFactor).clamped(to: 20...140)
                        annotationView.image = buildingIcon(source: source, size: iconSize)
                        annotationView.centerOffset = CGPoint(x: 0, y: -iconSize / 2)
                    }

                    annotationView.displayPriority = .required
                    return annotationView

                } else {
                    // SF Symbol：使用标准 MKMarkerAnnotationView
                    let identifier = "BuildingMarker"
                    let annotationView = mapView.dequeueReusableAnnotationView(
                        withIdentifier: identifier
                    ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: identifier
                    )

                    annotationView.annotation = annotation
                    annotationView.canShowCallout = true

                    let statusColor: UIColor
                    switch buildingAnnotation.building.status {
                    case .constructing: statusColor = .systemOrange
                    case .upgrading:    statusColor = .systemBlue
                    case .active:       statusColor = .systemGreen
                    case .inactive:     statusColor = .systemGray
                    case .damaged:      statusColor = .systemRed
                    }
                    annotationView.markerTintColor = statusColor

                    let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
                    annotationView.glyphImage = UIImage(systemName: iconName, withConfiguration: config)
                    annotationView.displayPriority = .required

                    return annotationView
                }
            }

            // 处理 POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIMarker"

                // 复用或创建新的标注视图
                let annotationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                annotationView.annotation = annotation
                annotationView.canShowCallout = true

                let poiKey = ExplorationManager.shared.coordKey(for: poiAnnotation.poi.coordinate)
                let isScavenged = parent.coolingDownPOIKeys.contains(poiKey)

                if isScavenged {
                    // 已搜刮：灰色 + 打勾图标 + 低优先级
                    annotationView.markerTintColor = .systemGray
                    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
                    annotationView.glyphImage = UIImage(systemName: "checkmark", withConfiguration: config)
                    annotationView.displayPriority = .defaultLow
                } else {
                    // 未搜刮：应用 POI 类型的颜色
                    annotationView.markerTintColor = poiAnnotation.poi.type.uiColor

                    // 设置自定义图标
                    let iconName = poiAnnotation.poi.type.icon
                    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
                    annotationView.glyphImage = UIImage(systemName: iconName, withConfiguration: config)

                    // 根据 POI 状态调整显示优先级
                    switch poiAnnotation.poi.status {
                    case .hasResources:
                        annotationView.displayPriority = .required
                    case .undiscovered, .discovered:
                        annotationView.displayPriority = .defaultHigh
                    case .looted:
                        annotationView.displayPriority = .defaultLow
                    case .dangerous:
                        annotationView.displayPriority = .required
                    }
                }

                return annotationView
            }

            return nil
        }

        /// 地图区域变化完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let newDelta = mapView.region.span.latitudeDelta
            let changeRatio = abs(newDelta - lastRegionLatDelta) / max(lastRegionLatDelta, 0.0001)
            guard changeRatio > 0.05 else { return }
            lastRegionLatDelta = newDelta
            updateBuildingIconSizes(in: mapView)
        }

        /// 根据当前缩放级别动态更新所有建筑图标尺寸
        func updateBuildingIconSizes(in mapView: MKMapView) {
            let latDelta = mapView.region.span.latitudeDelta
            let referenceSpan: CLLocationDegrees = 0.005
            let rawScale = referenceSpan / latDelta
            let scaleFactor = CGFloat(min(max(rawScale, 0.25), 3.0))

            for annotation in mapView.annotations {
                guard let buildingAnnotation = annotation as? BuildingAnnotation,
                      let view = mapView.view(for: annotation) as? MKAnnotationView else { continue }
                let iconName = buildingAnnotation.template?.icon ?? ""
                guard !iconName.contains("."), let source = UIImage(named: iconName) else { continue }

                let baseSize = CGFloat(buildingAnnotation.template?.mapIconSize ?? 60)
                let iconSize = (baseSize * scaleFactor).clamped(to: 20...140)
                view.image = buildingIcon(source: source, size: iconSize)
                view.centerOffset = CGPoint(x: 0, y: -iconSize / 2)
            }
        }

        /// 渲染建筑图标（透明背景，直接绘制原图）
        func buildingIcon(source: UIImage, size: CGFloat) -> UIImage {
            let sz = CGSize(width: size, height: size)
            let rect = CGRect(origin: .zero, size: sz)
            return UIGraphicsImageRenderer(size: sz).image { _ in
                if let cg = source.cgImage,
                   (cg.alphaInfo == .none || cg.alphaInfo == .noneSkipFirst || cg.alphaInfo == .noneSkipLast),
                   let masked = cg.copy(maskingColorComponents: [0, 50, 0, 50, 0, 50]) {
                    UIImage(cgImage: masked).draw(in: rect)
                } else {
                    source.draw(in: rect)
                }
            }
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图加载完成的回调
        }

        /// 用户位置获取失败
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("地图定位失败: \(error.localizedDescription)")
        }
    }

    // MARK: - POI标记管理

    /// 更新POI标记
    private func updatePOIAnnotations(on mapView: MKMapView, context: Context) {
        // 检查POI数量或搜刮数量是否变化，避免每次updateUIView都刷新标记
        let currentPOICount = nearbyPOIs.count
        let currentScavengedCount = coolingDownPOIKeys.count
        guard context.coordinator.lastPOICount != currentPOICount ||
              context.coordinator.lastScavengedCount != currentScavengedCount else { return }
        context.coordinator.lastPOICount = currentPOICount
        context.coordinator.lastScavengedCount = currentScavengedCount

        // 移除旧的POI标记
        let oldPOIAnnotations = mapView.annotations.filter { $0 is POIAnnotation }
        mapView.removeAnnotations(oldPOIAnnotations)

        // 添加新的POI标记
        let newAnnotations = nearbyPOIs.map { poi in
            POIAnnotation(poi: poi)
        }
        mapView.addAnnotations(newAnnotations)
    }

    // MARK: - 建筑标记管理

    /// 更新建筑标记
    private func updateBuildingAnnotations(on mapView: MKMapView, context: Context) {
        // 用 ID+坐标 哈希检测数量和位置变化
        let currentHash = buildings.map {
            "\($0.id)-\(String(format: "%.6f", $0.locationLat ?? 0))-\(String(format: "%.6f", $0.locationLon ?? 0))"
        }.joined(separator: ",")
        guard context.coordinator.lastBuildingsHash != currentHash else { return }
        context.coordinator.lastBuildingsHash = currentHash

        // 移除旧的建筑标记
        let oldBuildingAnnotations = mapView.annotations.filter { $0 is BuildingAnnotation }
        mapView.removeAnnotations(oldBuildingAnnotations)

        // 添加新的建筑标记
        for building in buildings {
            guard let coord = building.coordinate else { continue }
            let template = buildingTemplates.first { $0.templateId == building.templateId }
            let annotation = BuildingAnnotation(building: building, template: template)
            annotation.coordinate = coord
            mapView.addAnnotation(annotation)
        }

        // 添加后按当前缩放级别刷新图标尺寸
        DispatchQueue.main.async {
            context.coordinator.updateBuildingIconSizes(in: mapView)
        }

        if !buildings.isEmpty {
            print("🏗️ 更新建筑标记: \(buildings.count) 个")
        }
    }
}

// MARK: - POI Annotation

/// POI标记类
class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI
    /// MapKit返回的POI坐标在中国已经是GCJ-02，不需要再转换
    var coordinate: CLLocationCoordinate2D { poi.coordinate }
    var title: String? { poi.name }
    var subtitle: String? { poi.type.displayName }

    init(poi: POI) {
        self.poi = poi
    }
}

// MARK: - Building Annotation

/// 建筑标记类
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?

    /// 建筑坐标（数据库保存的已经是 GCJ-02 坐标）
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        template?.name ?? building.buildingName
    }

    var subtitle: String? {
        var parts: [String] = []
        parts.append("Lv.\(building.level)")
        parts.append(building.status.displayName)
        return parts.joined(separator: " · ")
    }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.template = template
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        super.init()
    }
}

// MARK: - CGFloat clamp helper

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil,
        explorationPath: [],
        explorationPathVersion: 0,
        isExploring: false
    )
}
