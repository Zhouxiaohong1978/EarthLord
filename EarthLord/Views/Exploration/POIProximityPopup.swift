//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI接近弹窗 - 玩家进入POI 50米范围时显示
//

import SwiftUI
import CoreLocation

struct POIProximityPopup: View {
    let poi: POI
    let onScavenge: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack(spacing: 12) {
                Image(systemName: poi.type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(poi.type.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现废墟")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(poi.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 危险等级
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundColor(index < poi.dangerLevel ? dangerColor : ApocalypseTheme.textMuted)
                        }
                        Text(dangerText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(dangerColor)
                    }
                }

                Spacer()
            }

            // 按钮
            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("稍后再说")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }

                Button {
                    onScavenge()
                } label: {
                    Text("立即搜刮")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, 32)
    }

    // MARK: - 危险等级辅助属性

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1: return ApocalypseTheme.success
        case 2: return ApocalypseTheme.info
        case 3: return ApocalypseTheme.warning
        case 4, 5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }

    /// 危险等级文字
    private var dangerText: String {
        switch poi.dangerLevel {
        case 1: return "安全"
        case 2: return "低风险"
        case 3: return "中等风险"
        case 4: return "高风险"
        case 5: return "极度危险"
        default: return "未知"
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        POIProximityPopup(
            poi: POI(
                name: "废弃超市",
                type: .supermarket,
                coordinate: .init(latitude: 0, longitude: 0),
                status: .undiscovered,
                description: "可能有食物和水"
            ),
            onScavenge: {},
            onDismiss: {}
        )
    }
}
