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
