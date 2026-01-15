//
//  LocationReporter.swift
//  EarthLord
//
//  位置上报服务 - 管理玩家位置的定时上报
//

import Foundation
import CoreLocation
import Combine
import Supabase
import UIKit

/// 位置上报服务
@MainActor
final class LocationReporter: ObservableObject {

    // MARK: - Singleton

    static let shared = LocationReporter()

    // MARK: - Constants

    /// 定时上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 移动触发上报的距离阈值（米）
    private let movementThreshold: CLLocationDistance = 50.0

    // MARK: - Published Properties

    /// 最后上报时间
    @Published var lastReportedAt: Date?

    /// 上报状态
    @Published var isReporting: Bool = false

    /// 错误信息
    @Published var lastError: String?

    // MARK: - Private Properties

    /// 定时上报计时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocation?

    /// 位置订阅
    private var locationCancellable: AnyCancellable?

    /// 应用生命周期订阅
    private var lifecycleCancellables = Set<AnyCancellable>()

    /// 日志器
    private let logger = ExplorationLogger.shared

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Initialization

    private init() {
        setupLifecycleObservers()
        logger.log("LocationReporter 初始化完成", type: .info)
    }

    // MARK: - Lifecycle

    /// 设置应用生命周期监听
    private func setupLifecycleObservers() {
        // 应用进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.logger.log("应用进入前台，恢复位置上报", type: .info)
                    self?.resumeReporting()
                }
            }
            .store(in: &lifecycleCancellables)

        // 应用进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.logger.log("应用进入后台，标记离线", type: .info)
                    await self?.markOffline()
                    self?.pauseReporting()
                }
            }
            .store(in: &lifecycleCancellables)

        // 应用即将终止
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.logger.log("应用即将终止，标记离线", type: .info)
                    await self?.markOffline()
                }
            }
            .store(in: &lifecycleCancellables)
    }

    // MARK: - Public Methods

    /// 启动位置上报服务
    func startReporting() {
        guard AuthManager.shared.isAuthenticated else {
            logger.log("用户未登录，跳过位置上报", type: .warning)
            return
        }

        logger.log("位置上报服务启动", type: .info)

        // 立即上报一次
        Task {
            await reportCurrentLocation()
        }

        // 启动定时上报
        startReportTimer()

        // 监听位置变化（移动触发上报）
        subscribeToLocationUpdates()
    }

    /// 停止位置上报服务
    func stopReporting() {
        stopReportTimer()
        locationCancellable?.cancel()
        locationCancellable = nil
        logger.log("位置上报服务已停止", type: .info)
    }

    /// 立即上报当前位置
    func reportCurrentLocation() async {
        guard AuthManager.shared.isAuthenticated else {
            logger.log("用户未登录，无法上报位置", type: .warning)
            return
        }

        // 获取当前位置
        guard let coordinate = LocationManager.shared.userLocation else {
            logger.log("无法获取当前位置", type: .warning)
            return
        }

        await reportLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// 标记玩家离线
    func markOffline() async {
        guard AuthManager.shared.isAuthenticated else { return }

        do {
            try await supabase.rpc("mark_player_offline").execute()
            logger.log("已标记为离线", type: .info)
        } catch {
            logger.logError("标记离线失败", error: error)
        }
    }

    // MARK: - Private Methods

    /// 恢复上报（从后台返回前台）
    private func resumeReporting() {
        guard AuthManager.shared.isAuthenticated else { return }

        // 立即上报一次
        Task {
            await reportCurrentLocation()
        }

        // 重新启动定时器
        startReportTimer()
    }

    /// 暂停上报（进入后台）
    private func pauseReporting() {
        stopReportTimer()
    }

    /// 启动定时上报计时器
    private func startReportTimer() {
        stopReportTimer()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportCurrentLocation()
            }
        }

        logger.log("定时上报计时器已启动，间隔 \(Int(reportInterval)) 秒", type: .info)
    }

    /// 停止定时上报计时器
    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
    }

    /// 订阅位置更新（移动触发上报）
    private func subscribeToLocationUpdates() {
        locationCancellable?.cancel()

        locationCancellable = LocationManager.shared.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                Task { @MainActor in
                    self?.checkMovementAndReport(newCoordinate: coordinate)
                }
            }
    }

    /// 检测移动距离并触发上报
    private func checkMovementAndReport(newCoordinate: CLLocationCoordinate2D) {
        let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)

        // 如果有上次上报的位置，检查移动距离
        if let lastLocation = lastReportedLocation {
            let distance = newLocation.distance(from: lastLocation)

            if distance >= movementThreshold {
                logger.log("移动距离 \(String(format: "%.1f", distance))m 超过阈值，立即上报", type: .info)

                Task {
                    await reportLocation(
                        latitude: newCoordinate.latitude,
                        longitude: newCoordinate.longitude
                    )
                }
            }
        }
    }

    /// 上报位置到服务器
    private func reportLocation(latitude: Double, longitude: Double, isOnline: Bool = true) async {
        guard !isReporting else {
            return
        }

        isReporting = true
        defer { isReporting = false }

        do {
            // 调用 RPC 函数上报位置
            try await supabase.rpc(
                "report_location",
                params: [
                    "p_latitude": latitude,
                    "p_longitude": longitude
                ]
            ).execute()

            // 更新状态
            lastReportedAt = Date()
            lastReportedLocation = CLLocation(latitude: latitude, longitude: longitude)
            lastError = nil

            logger.log("位置上报成功: (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))", type: .success)

        } catch {
            lastError = error.localizedDescription
            logger.logError("位置上报失败", error: error)
        }
    }
}
