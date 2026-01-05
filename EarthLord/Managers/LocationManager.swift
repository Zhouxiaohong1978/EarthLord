//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取和权限管理
//

import Foundation
import CoreLocation
import Combine  // @Published 需要这个框架

// MARK: - LocationManager 定位管理器

/// 管理 GPS 定位和权限请求
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation: Bool = false

    // MARK: - 路径追踪 Published Properties

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否已闭合（Day16 圈地判定会用）
    @Published var isPathClosed: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager: CLLocationManager

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 最小记录距离（米）- 移动超过此距离才记录新点
    private let minimumRecordDistance: CLLocationDistance = 10.0

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否权限状态未确定
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 当前路径点数
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        // 获取初始授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米就更新（追踪时需要更频繁）
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        // 清除之前的错误
        locationError = nil

        // 请求"使用App期间"权限
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始获取位置更新
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未授权定位权限"
            return
        }

        locationError = nil
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    /// 停止位置更新
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置更新
    func requestLocation() {
        guard isAuthorized else {
            locationError = "未授权定位权限"
            return
        }

        locationError = nil
        locationManager.requestLocation()
    }

    // MARK: - 路径追踪 Public Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未授权定位权限，无法追踪"
            return
        }

        // 清除之前的路径
        clearPath()

        // 标记开始追踪
        isTracking = true
        isPathClosed = false

        // 确保正在更新位置
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果有当前位置，立即记录第一个点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.recordPathPoint()
            }
        }

        print("📍 开始路径追踪")
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记停止追踪
        isTracking = false

        print("📍 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    // MARK: - 路径追踪 Private Methods

    /// 定时器回调 - 判断是否记录新点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else { return }

        // 如果是第一个点，直接记录
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 记录第一个点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return
        }

        // 计算与上一个点的距离
        guard let lastCoordinate = pathCoordinates.last else { return }

        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 只有移动超过最小距离才记录新点
        if distance >= minimumRecordDistance {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 记录新点 #\(pathCoordinates.count): 距上个点 \(String(format: "%.1f", distance))米")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            self.authorizationStatus = newStatus

            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // 授权成功，开始定位
                self.locationError = nil
                self.startUpdatingLocation()

            case .denied:
                // 用户拒绝授权
                self.locationError = "您已拒绝定位权限，无法显示您的位置"
                self.stopUpdatingLocation()
                // 如果正在追踪，也要停止
                if self.isTracking {
                    self.stopPathTracking()
                }

            case .restricted:
                // 定位受限（如家长控制）
                self.locationError = "定位功能受到限制"
                self.stopUpdatingLocation()

            case .notDetermined:
                // 尚未决定
                break

            @unknown default:
                break
            }
        }
    }

    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // 更新用户位置
            self.userLocation = location.coordinate
            self.locationError = nil

            // ⭐ 关键：更新 currentLocation，供 Timer 采点使用
            self.currentLocation = location
        }
    }

    /// 定位失败回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // 处理定位错误
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置信息"
                case .network:
                    self.locationError = "网络错误，无法定位"
                default:
                    self.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}
