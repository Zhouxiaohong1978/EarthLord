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

    /// 更新视图（空实现，居中逻辑在 Coordinator 中处理）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 居中逻辑在 Coordinator 的 didUpdate userLocation 中处理
        // 这里不需要额外操作
    }

    /// 创建 Coordinator 代理
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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

        /// 地图区域变化完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 用户手动拖动地图后的处理
            // 由于 hasInitialCentered 已设置，不会再自动居中
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
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false)
    )
}
