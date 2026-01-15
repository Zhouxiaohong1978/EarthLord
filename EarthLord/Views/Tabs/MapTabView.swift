//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图和用户位置
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit
import Auth

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（全局共享）
    @EnvironmentObject var locationManager: LocationManager

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位居中
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传结果提示
    @State private var uploadResultMessage: String?

    /// 是否显示上传结果
    @State private var showUploadResult = false

    /// 圈地开始时间（用于记录）
    @State private var trackingStartTime: Date?

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告横幅
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 探索管理器（单例，使用 ObservedObject 观察）
    @ObservedObject private var explorationManager = ExplorationManager.shared

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult = false

    /// 探索失败弹窗
    @State private var showExplorationFailed = false

    /// 探索失败原因
    @State private var explorationFailReason: String = ""

    /// 探索统计数据（累计距离、排名）
    @State private var explorationStats: ExplorationStats?

    /// 是否显示日志查看器
    @State private var showLogViewer = false

    // MARK: - 计算属性

    /// 当前用户 ID
    private var currentUserId: String? {
        AuthManager.shared.currentUser?.id.uuidString
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // MARK: 底层地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: AuthManager.shared.currentUser?.id.uuidString,
                explorationPath: explorationManager.explorationPathCoordinates,
                explorationPathVersion: explorationManager.explorationPathVersion,
                isExploring: explorationManager.isExploring,
                nearbyPOIs: explorationManager.nearbyPOIs
            )
            .ignoresSafeArea()

            // MARK: 覆盖层 UI
            VStack {
                // 顶部状态栏
                topStatusBar

                // 速度警告横幅（圈地）
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // 探索超速警告横幅
                if case .overSpeedWarning(let seconds) = explorationManager.explorationState {
                    explorationSpeedWarningBanner(countdown: seconds)
                }

                // 探索状态覆盖层
                if explorationManager.isExploring {
                    explorationStatusOverlay
                }

                // 验证结果横幅
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 上传结果提示
                if showUploadResult, let message = uploadResultMessage {
                    uploadResultBanner(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 确认登记按钮（验证通过时显示）
                if locationManager.territoryValidationPassed && !isUploading {
                    confirmRegisterButton
                        .transition(.scale.combined(with: .opacity))
                        .padding(.top, 8)
                }

                Spacer()

                // 底部控制栏
                bottomControlBar
            }

            // MARK: 权限被拒绝时的提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }
        }
        .overlay {
            // POI接近弹窗
            if explorationManager.showProximityPopup,
               let poi = explorationManager.currentProximityPOI {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        explorationManager.showProximityPopup = false
                    }

                POIProximityPopup(
                    poi: poi,
                    onScavenge: {
                        Task {
                            explorationManager.showProximityPopup = false
                            await explorationManager.scavengePOI(poi)
                        }
                    },
                    onDismiss: {
                        explorationManager.showProximityPopup = false
                    }
                )
            }

            // 搜刮结果弹窗
            if explorationManager.showScavengeResult,
               let result = explorationManager.scavengeResult {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                ScavengeResultView(
                    result: result,
                    onConfirm: {
                        Task {
                            await explorationManager.confirmScavengeResult()
                        }
                    },
                    onDiscard: {
                        explorationManager.discardScavengeResult()
                    }
                )
            }
        }
        .onAppear {
            // 首次出现时请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // 加载领地数据
            Task {
                await loadTerritories()
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        // 探索结果弹窗
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationManager.explorationResult {
                // 转换为 Mock 模型以兼容现有 UI
                let mockResult = convertToMockResult(result)
                ExplorationResultView(result: mockResult)
            }
        }
        // 探索失败弹窗
        .alert("探索失败", isPresented: $showExplorationFailed) {
            Button("确定", role: .cancel) {
                explorationManager.resetExplorationState()
            }
        } message: {
            Text(explorationFailReason)
        }
        // 监听探索状态变化
        .onReceive(explorationManager.$explorationState) { state in
            handleExplorationStateChange(state)
        }
        // 日志查看器
        .sheet(isPresented: $showLogViewer) {
            ExplorationLogView()
        }
    }

    // MARK: - 顶部状态栏

    private var topStatusBar: some View {
        HStack {
            // 定位状态指示
            HStack(spacing: 8) {
                Circle()
                    .fill(locationManager.isAuthorized ? ApocalypseTheme.success : ApocalypseTheme.warning)
                    .frame(width: 8, height: 8)

                Text(locationStatusText)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground.opacity(0.9))
            .cornerRadius(20)

            Spacer()

            // 调试日志按钮
            Button(action: { showLogViewer = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption)
                    Text("日志")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(12)
            }

            // 坐标显示
            if let location = userLocation {
                Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 定位状态文字
    private var locationStatusText: String {
        if locationManager.isDenied {
            return "定位已禁用"
        } else if locationManager.isAuthorized {
            return hasLocatedUser ? "已定位" : "定位中..."
        } else {
            return "等待授权"
        }
    }

    // MARK: - 验证结果横幅

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 速度警告横幅

    /// 速度警告横幅
    private var speedWarningBanner: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            if let warning = locationManager.speedWarning {
                Text(warning)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // 根据是否还在追踪选择颜色
            (locationManager.isTracking ? Color.yellow : Color.red)
                .opacity(0.9)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // 3 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    locationManager.speedWarning = nil
                }
            }
        }
    }

    // MARK: - 底部控制栏

    private var bottomControlBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 左侧：圈地按钮
            trackingButton

            // 中间：定位按钮
            Button(action: {
                centerToUserLocation()
            }) {
                Image(systemName: hasLocatedUser ? "location.fill" : "location")
                    .font(.system(size: 20))
                    .foregroundColor(hasLocatedUser ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(!locationManager.isAuthorized)
            .opacity(locationManager.isAuthorized ? 1 : 0.5)

            // 右侧：探索按钮
            exploreButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 圈地按钮

    /// 圈地追踪按钮
    private var trackingButton: some View {
        Button(action: {
            toggleTracking()
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                // 文字
                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.subheadline.bold())

                    // 显示当前点数
                    Text("(\(locationManager.pathPointCount))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("开始圈地")
                        .font(.subheadline.bold())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1 : 0.5)
        // 追踪时添加脉冲动画
        .overlay(
            Capsule()
                .stroke(Color.red, lineWidth: 2)
                .scaleEffect(locationManager.isTracking ? 1.2 : 1.0)
                .opacity(locationManager.isTracking ? 0 : 1)
                .animation(
                    locationManager.isTracking ?
                        Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false) :
                        .default,
                    value: locationManager.isTracking
                )
        )
    }

    // MARK: - 探索按钮

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            toggleExploration()
        }) {
            HStack(spacing: 8) {
                if explorationManager.isExploring {
                    // 探索中状态
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))

                    Text("结束探索")
                        .font(.subheadline.bold())
                } else {
                    // 正常状态
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16))

                    Text("探索")
                        .font(.subheadline.bold())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(explorationManager.isExploring ? Color.orange : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1 : 0.5)
    }

    /// 切换探索状态
    private func toggleExploration() {
        print("🔘 [MapTabView] toggleExploration 被调用")
        print("  - 当前探索状态: \(explorationManager.isExploring)")
        print("  - 定位授权状态: \(locationManager.isAuthorized)")

        if explorationManager.isExploring {
            // 结束探索
            print("  - 执行: 停止探索")
            explorationManager.stopExploration()
        } else {
            // 开始探索
            print("  - 执行: 开始探索")
            explorationManager.startExploration()
        }

        print("  - 新探索状态: \(explorationManager.isExploring)")
    }

    /// 切换追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // Day 19: 停止时完全清除碰撞监控
            stopCollisionMonitoring()
            locationManager.stopPathTracking()
        } else {
            // Day 19: 开始圈地前检测起始点
            startClaimingWithCollisionCheck()
        }
    }

    /// 居中到用户位置
    private func centerToUserLocation() {
        if locationManager.isNotDetermined {
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            locationManager.requestLocation()
            // 重置居中标志，让地图再次居中
            hasLocatedUser = false
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = TerritoryManager.shared.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            withAnimation {
                showCollisionWarning = true
            }

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCollisionWarning = false
                    collisionWarning = nil
                    collisionWarningLevel = .safe
                }
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        withAnimation {
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe
        }
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = TerritoryManager.shared.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            withAnimation {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            withAnimation {
                showCollisionWarning = true
            }

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showCollisionWarning = false
                    collisionWarning = nil
                    collisionWarningLevel = .safe
                }
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 18))

            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor.opacity(0.95))
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 权限被拒绝提示卡片

    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("无法获取位置")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("您已拒绝定位权限。要在末日世界中显示您的位置，请在设置中开启定位权限。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // 前往设置按钮
            Button(action: {
                openSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(25)
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 32)
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 确认登记按钮

    /// 确认登记领地按钮
    private var confirmRegisterButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                }

                Text(isUploading ? "登记中..." : "确认登记领地")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isUploading)
        .padding(.horizontal, 16)
    }

    // MARK: - 上传结果横幅

    /// 上传结果提示横幅
    private func uploadResultBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(message.contains("成功") ? Color.green : Color.red)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 上传领地方法

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadError(String(localized: "领地验证未通过，无法上传"))
            return
        }

        // 检查是否已登录
        guard AuthManager.shared.isAuthenticated else {
            showUploadError(String(localized: "请先登录后再登记领地"))
            return
        }

        isUploading = true

        do {
            try await TerritoryManager.shared.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: trackingStartTime ?? Date()
            )

            // 上传成功
            await MainActor.run {
                isUploading = false
                showUploadSuccess(String(localized: "领地登记成功！"))

                // Day 19: 停止碰撞监控
                stopCollisionMonitoring()

                // 关键：上传成功后重置所有状态
                locationManager.stopPathTracking(clearAllState: true)

                // 重置开始时间
                trackingStartTime = nil
            }

            // 刷新领地列表（在地图上显示新领地）
            await loadTerritories()

        } catch {
            await MainActor.run {
                isUploading = false
                showUploadError(String(format: String(localized: "上传失败: %@"), error.localizedDescription))
            }
        }
    }

    /// 显示上传成功提示
    private func showUploadSuccess(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
            showValidationBanner = false  // 隐藏验证横幅
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResult = false
                uploadResultMessage = nil
            }
        }
    }

    /// 显示上传错误提示
    private func showUploadError(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResult = false
                uploadResultMessage = nil
            }
        }
    }

    // MARK: - 领地加载

    /// 从云端加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await TerritoryManager.shared.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - 探索状态覆盖层

    /// 当前奖励等级
    private var currentRewardTier: RewardTier {
        RewardTier.from(distance: explorationManager.totalDistance)
    }

    /// 距离下一等级还需要多少米
    private var distanceToNextTier: Double? {
        RewardTier.distanceToNextTier(currentDistance: explorationManager.totalDistance)
    }

    /// 奖励等级颜色
    private var rewardTierColor: Color {
        switch currentRewardTier {
        case .none:
            return .gray
        case .bronze:
            return Color(red: 0.8, green: 0.5, blue: 0.2)  // 铜色
        case .silver:
            return Color(red: 0.75, green: 0.75, blue: 0.8)  // 银色
        case .gold:
            return Color(red: 1.0, green: 0.84, blue: 0.0)  // 金色
        case .diamond:
            return Color(red: 0.0, green: 0.9, blue: 1.0)  // 钻石蓝
        }
    }

    /// 探索状态覆盖层
    private var explorationStatusOverlay: some View {
        VStack(spacing: 8) {
            // 第一行：距离、速度、时长
            HStack(spacing: 16) {
                // 行走距离
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(formatExplorationDistance(explorationManager.totalDistance))
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Divider()
                    .frame(height: 30)
                    .background(ApocalypseTheme.textMuted)

                // 当前速度
                VStack(spacing: 2) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 14))
                        .foregroundColor(explorationSpeedColor)
                    Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundColor(explorationSpeedColor)
                }

                Divider()
                    .frame(height: 30)
                    .background(ApocalypseTheme.textMuted)

                // 探索时长
                VStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.info)
                    Text(formatExplorationDuration(explorationManager.explorationDuration))
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            // 第二行：奖励等级和距离下一等级
            HStack(spacing: 8) {
                // 当前奖励等级
                HStack(spacing: 4) {
                    Image(systemName: currentRewardTier.icon)
                        .font(.system(size: 12))
                        .foregroundColor(rewardTierColor)
                    Text(currentRewardTier.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(rewardTierColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rewardTierColor.opacity(0.15))
                .cornerRadius(8)

                // 距离下一等级
                if let distance = distanceToNextTier, let nextTier = currentRewardTier.nextTier {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text("距\(nextTier.displayName)还需")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(formatExplorationDistance(distance))
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                } else {
                    // 已达到最高等级
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundColor(rewardTierColor)
                        Text("已达最高等级!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(rewardTierColor)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 探索速度颜色
    private var explorationSpeedColor: Color {
        if explorationManager.currentSpeed > 20 {
            return .red  // 超速
        } else if explorationManager.currentSpeed > 15 {
            return .orange  // 接近限速
        } else {
            return ApocalypseTheme.success  // 安全
        }
    }

    /// 探索超速警告横幅
    private func explorationSpeedWarningBanner(countdown: Int) -> some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("速度过快！请降低速度")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Text("当前速度:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)

                    Text("· 剩余")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(countdown)秒")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundColor(.yellow)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.red.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - 探索状态处理

    /// 处理探索状态变化
    private func handleExplorationStateChange(_ state: ExplorationState) {
        switch state {
        case .idle:
            // 空闲状态，不需要处理
            break

        case .exploring:
            // 探索中，不需要特殊处理
            break

        case .overSpeedWarning:
            // 超速警告，触发震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .completed:
            // 探索完成，先获取统计数据再显示结果
            Task {
                do {
                    // 清除缓存以获取最新数据
                    ExplorationStatsManager.shared.clearCache()
                    explorationStats = try await ExplorationStatsManager.shared.getStats()
                } catch {
                    // 获取统计失败，使用默认值
                    explorationStats = nil
                }
                // 显示结果弹窗
                showExplorationResult = true
            }

        case .failed(let reason):
            // 探索失败，显示失败弹窗
            explorationFailReason = reason.description
            showExplorationFailed = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// 格式化探索距离
    private func formatExplorationDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化探索时长
    private func formatExplorationDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// 转换探索结果为 Mock 模型
    private func convertToMockResult(_ result: ExplorationSessionResult) -> ExplorationResult {
        // 转换物品列表
        let obtainedItems = result.obtainedItems.map { item in
            ObtainedItem(
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality
            )
        }

        // 使用真实统计数据（如果有的话）
        let totalDistance = explorationStats?.totalDistance ?? result.distanceWalked
        let rank = explorationStats?.distanceRank ?? 1

        return ExplorationResult(
            id: result.id,
            startTime: result.startTime,
            endTime: result.endTime,
            distanceStats: DistanceStats(
                current: result.distanceWalked,
                total: totalDistance,
                rank: rank
            ),
            discoveredPOIs: [],
            obtainedItems: obtainedItems,
            experienceGained: Int(result.distanceWalked / 10),  // 每10米1经验
            rewardTier: result.rewardTier.rawValue
        )
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager.shared)
}
