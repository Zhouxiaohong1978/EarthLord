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

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

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
                hasLocatedUser: $hasLocatedUser
            )
            .ignoresSafeArea()

            // MARK: 覆盖层 UI
            VStack {
                // 顶部状态栏
                topStatusBar

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

    // MARK: - 底部控制栏

    private var bottomControlBar: some View {
        HStack {
            Spacer()

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
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
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
}
