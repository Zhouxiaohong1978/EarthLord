import SwiftUI
import CoreLocation
import CoreMotion
import UserNotifications

struct LocationPermissionView: View {
    var onGranted: () -> Void
    var onSkip: () -> Void

    @StateObject private var permissionManager = PermissionRequestManager()

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 52))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 28)

                    // 标题
                    Text("开始之前，需要三项授权")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    // 副标题
                    Text("末日之主的核心玩法依赖以下权限\n全部允许后即可开始生存之旅")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 28)

                    // 权限说明卡片
                    VStack(spacing: 0) {
                        permissionRow(
                            icon: "location.fill",
                            color: .blue,
                            badge: "1",
                            title: "位置（精确 + 后台）",
                            desc: "圈地占领、废墟搜刮、后台轨迹记录"
                        )
                        Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                        permissionRow(
                            icon: "waveform.path.ecg",
                            color: .pink,
                            badge: "2",
                            title: "运动与健身",
                            desc: "识别步行 / 骑车 / 驾车，仅步行时计算探索距离"
                        )
                        Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                        permissionRow(
                            icon: "bell.badge.fill",
                            color: .orange,
                            badge: "3",
                            title: "通知",
                            desc: "领地被入侵、物资就绪、每日探索提醒"
                        )
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // 提示文字
                    Text("点击下方按钮后，系统将依次弹出三次授权确认")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    // 隐私承诺
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.success)
                        Text("数据仅用于游戏功能，不会出售或用于广告")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.bottom, 24)

                    // 一键授权按钮
                    Button {
                        permissionManager.requestAll {
                            onGranted()
                        }
                    } label: {
                        Text("一键授权（共三步）")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // 暂不允许
                    Button {
                        onSkip()
                    } label: {
                        Text("暂不允许（部分功能不可用）")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.vertical, 8)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func permissionRow(icon: String, color: Color, badge: String, title: LocalizedStringKey, desc: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                // 序号角标
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 6, y: -6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - PermissionRequestManager

/// 依次申请：位置（WhenInUse → Always）→ 运动传感器 → 通知
@MainActor
final class PermissionRequestManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var onAllDone: (() -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestAll(onDone: @escaping () -> Void) {
        self.onAllDone = onDone
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // 位置已授权，直接升级到 always 并继续后续步骤
            locationManager.requestAlwaysAuthorization()
            requestMotionThenNotification()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            switch status {
            case .authorizedWhenInUse:
                // 获得前台权限后请求后台
                manager.requestAlwaysAuthorization()
                requestMotionThenNotification()
            case .authorizedAlways:
                requestMotionThenNotification()
            case .denied, .restricted:
                // 位置被拒，仍继续运动+通知
                requestMotionThenNotification()
            default:
                break
            }
        }
    }

    /// 第2步：运动传感器权限
    private func requestMotionThenNotification() {
        let activityManager = CMMotionActivityManager()
        let now = Date()
        activityManager.queryActivityStarting(from: now, to: now, to: .main) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.requestNotification()
            }
        }
    }

    /// 第3步：通知权限
    private func requestNotification() {
        Task {
            await NotificationManager.shared.requestPermission()
            await MainActor.run {
                onAllDone?()
            }
        }
    }
}

#Preview {
    LocationPermissionView(onGranted: {}, onSkip: {})
}
