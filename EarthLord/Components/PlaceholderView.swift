//
//  PlaceholderView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

/// 通用占位视图
struct PlaceholderView: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
}
