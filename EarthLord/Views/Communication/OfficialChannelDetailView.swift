//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道 - Day 34 实现
//

import SwiftUI

struct OfficialChannelDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "megaphone")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("官方频道")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("Day 34 实现")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    OfficialChannelDetailView()
}
