//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道 - Day 33 实现
//

import SwiftUI

struct CreateChannelSheet: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("创建频道")
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
    CreateChannelSheet()
}
