//
//  TradeStatusBadge.swift
//  EarthLord
//
//  交易状态标签组件
//  显示挂单状态（挂单中/已完成/已取消/已过期）
//

import SwiftUI

struct TradeStatusBadge: View {
    let status: TradeOfferStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(TradeOfferStatus.allCases, id: \.self) { status in
            TradeStatusBadge(status: status)
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
