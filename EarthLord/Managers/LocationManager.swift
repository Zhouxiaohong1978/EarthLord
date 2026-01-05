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

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager: CLLocationManager

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    /// 最小记录距离（米）- 移动超过此距离才记录新点
    private let minimumRecordDistance: CLLocationDistance = 10.0

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 闭环距离阈值（米）- 当前位置距起点小于此值则认为闭环
    private let closureDistanceThreshold: CLLocationDistance = 30.0

    /// 最少路径点数 - 闭环至少需要的点数
    private let minimumPathPoints: Int = 10

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度暂停阈值（km/h）
    private let speedPauseThreshold: Double = 30.0

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

        // 添加日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记停止追踪
        isTracking = false

        print("📍 停止路径追踪，共记录 \(pathCoordinates.count) 个点")

        // 添加日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
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
            lastLocationTimestamp = Date()
            print("📍 记录第一个点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return
        }

        // ⭐ 速度检测 - 超速时不记录该点
        if !validateMovementSpeed(newLocation: location) {
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
            lastLocationTimestamp = Date()
            print("📍 记录新点 #\(pathCoordinates.count): 距上个点 \(String(format: "%.1f", distance))米")

            // 添加日志
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

            // ⭐ 闭环检测 - 每次记录新点后检测是否闭环
            checkPathClosure()
        }
    }

    // MARK: - 闭环检测

    /// 检测路径是否闭合
    private func checkPathClosure() {
        // 如果已经闭环，不再重复检测
        if isPathClosed {
            return
        }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔍 闭环检测：点数不足 (\(pathCoordinates.count)/\(minimumPathPoints))")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        // 距离小于阈值则闭环成功
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ 闭环检测成功！距起点 \(String(format: "%.1f", distanceToStart)) 米，共 \(pathCoordinates.count) 个点")

            // 添加日志 - 闭环成功
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m", type: .success)
        } else {
            print("🔍 闭环检测：距起点 \(String(format: "%.1f", distanceToStart)) 米（需要 ≤ \(closureDistanceThreshold) 米）")

            // 添加日志 - 距离信息
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distanceToStart))m (需≤30m)", type: .info)
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度是否合理
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 获取上次时间戳
        guard let lastTimestamp = lastLocationTimestamp else {
            // 第一次记录，无法计算速度
            return true
        }

        // 获取上个点
        guard let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算时间差（秒）
        let timeDelta = Date().timeIntervalSince(lastTimestamp)
        guard timeDelta > 0 else {
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算速度（km/h）
        let speedKmh = (distance / timeDelta) * 3.6

        // 清除之前的警告
        if speedKmh < speedWarningThreshold {
            speedWarning = nil
            isOverSpeed = false
        }

        // 检查是否超过暂停阈值（30 km/h）
        if speedKmh > speedPauseThreshold {
            speedWarning = "移动速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，已停止追踪"
            isOverSpeed = true
            stopPathTracking()
            print("⚠️ 速度超限：\(String(format: "%.1f", speedKmh)) km/h > \(speedPauseThreshold) km/h，停止追踪")

            // 添加日志 - 超速停止
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            return false
        }

        // 检查是否超过警告阈值（15 km/h）
        if speedKmh > speedWarningThreshold {
            speedWarning = "移动速度较快 (\(String(format: "%.1f", speedKmh)) km/h)，请放慢速度"
            isOverSpeed = true
            print("⚠️ 速度警告：\(String(format: "%.1f", speedKmh)) km/h > \(speedWarningThreshold) km/h")

            // 添加日志 - 速度警告
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            return true  // 警告但继续记录
        }

        return true
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
