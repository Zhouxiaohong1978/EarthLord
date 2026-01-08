//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图和用户位置
//

import SwiftUI
import MapKit
import CoreLocation
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
                currentUserId: AuthManager.shared.currentUser?.id.uuidString
            )
            .ignoresSafeArea()

            // MARK: 覆盖层 UI
            VStack {
                // 顶部状态栏
                topStatusBar

                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
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
        HStack(alignment: .bottom) {
            Spacer()

            VStack(spacing: 12) {
                // 圈地按钮
                trackingButton

                // 定位按钮
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
            }
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

    /// 切换追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            locationManager.stopPathTracking()
        } else {
            // 记录开始时间
            trackingStartTime = Date()
            locationManager.startPathTracking()
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
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 检查是否已登录
        guard AuthManager.shared.isAuthenticated else {
            showUploadError("请先登录后再登记领地")
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
                showUploadSuccess("领地登记成功！")

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
                showUploadError("上传失败: \(error.localizedDescription)")
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
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
