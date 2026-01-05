//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图和用户位置
//

import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（全局共享）
    @EnvironmentObject var locationManager: LocationManager

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位居中
    @State private var hasLocatedUser = false

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
                isPathClosed: locationManager.isPathClosed
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
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
