//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情 - Day 33 实现
//

import SwiftUI

struct ChannelDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "info.circle")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("频道详情")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("Day 33 实现")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    ChannelDetailView()
}
