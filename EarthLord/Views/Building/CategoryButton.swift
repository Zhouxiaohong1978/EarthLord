//
//  CategoryButton.swift
//  EarthLord
//
//  建筑分类按钮组件
//

import SwiftUI

/// 建筑分类按钮
struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : color)
        }
        .buttonStyle(.plain)
    }
}

/// 全部分类按钮（无图标版本）
struct AllCategoryButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(localized: "全部"))
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? ApocalypseTheme.primary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ApocalypseTheme.primary.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                )
                .foregroundColor(isSelected ? .white : ApocalypseTheme.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // 分类按钮示例
        HStack(spacing: 8) {
            AllCategoryButton(isSelected: true) {}
            CategoryButton(
                title: "生存",
                icon: "flame.fill",
                color: ApocalypseTheme.primary,
                isSelected: false
            ) {}
            CategoryButton(
                title: "储存",
                icon: "archivebox.fill",
                color: ApocalypseTheme.info,
                isSelected: false
            ) {}
        }

        HStack(spacing: 8) {
            AllCategoryButton(isSelected: false) {}
            CategoryButton(
                title: "生产",
                icon: "hammer.fill",
                color: ApocalypseTheme.success,
                isSelected: true
            ) {}
            CategoryButton(
                title: "能源",
                icon: "bolt.fill",
                color: ApocalypseTheme.warning,
                isSelected: false
            ) {}
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
