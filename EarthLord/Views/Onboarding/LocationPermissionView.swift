import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    var onGranted: () -> Void
    var onSkip: () -> Void

    @StateObject private var locationManager = LocationPermissionManager()

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "location.fill")
                        .font(.system(size: 52))
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .padding(.bottom, 32)

                // 标题
                Text("需要获取你的位置")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.bottom, 12)

                // 副标题
                Text("末日之主的核心玩法基于真实地理位置\n以下功能需要你的授权才能使用")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 36)

                // 用途说明卡片
                VStack(spacing: 0) {
                    permissionRow(
                        icon: "flag.fill",
                        color: .green,
                        title: "圈地占领",
                        desc: "步行圈定真实地图上的领地范围"
                    )
                    Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                    permissionRow(
                        icon: "figure.walk",
                        color: .blue,
                        title: "步行探索",
                        desc: "记录步行轨迹，计算距离并发放物资奖励"
                    )
                    Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                    permissionRow(
                        icon: "mappin.and.ellipse",
                        color: .cyan,
                        title: "废墟搜刮",
                        desc: "检测你是否靠近医院、超市等真实地点"
                    )
                    Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                    permissionRow(
                        icon: "location.fill",
                        color: .orange,
                        title: "后台定位",
                        desc: "探索时切换至其他App，轨迹记录不中断"
                    )
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // 隐私承诺
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.success)
                    Text("位置数据仅用于游戏功能，不会出售或用于广告")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 32)

                // 允许按钮
                Button {
                    locationManager.requestPermission {
                        onGranted()
                    }
                } label: {
                    Text("允许使用位置")
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
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func permissionRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
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

// MARK: - LocationPermissionManager

@MainActor
final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onGranted: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // 已授权，直接升级到 always
            manager.requestAlwaysAuthorization()
            onGranted()
        } else {
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse {
                // 获得前台授权后，申请后台授权
                manager.requestAlwaysAuthorization()
                onGranted?()
            } else if status == .authorizedAlways {
                onGranted?()
            }
        }
    }
}

#Preview {
    LocationPermissionView(onGranted: {}, onSkip: {})
}
