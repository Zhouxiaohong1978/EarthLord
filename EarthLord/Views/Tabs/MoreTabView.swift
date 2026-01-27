//
//  MoreTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - 更多菜单行组件

struct MoreMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MoreTabView()
}
