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

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager: CLLocationManager

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

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        // 获取初始授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新
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
