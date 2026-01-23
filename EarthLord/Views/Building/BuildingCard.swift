//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件 - 用于建筑浏览器网格
//

import SwiftUI

/// 建筑卡片
struct BuildingCard: View {
    let template: BuildingTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 建筑图标
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .foregroundColor(template.category.color)
                }

                // 建筑名称
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 分类标签
                Text(template.category.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(template.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(template.category.color.opacity(0.15))
                    )

                // 建造时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(template.formattedBuildTime)
                        .font(.system(size: 11))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 建筑卡片（带选中状态）
struct SelectableBuildingCard: View {
    let template: BuildingTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 建筑图标
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(isSelected ? 0.3 : 0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .foregroundColor(template.category.color)

                    // 选中标记
                    if isSelected {
                        Circle()
                            .stroke(template.category.color, lineWidth: 3)
                            .frame(width: 66, height: 66)
                    }
                }

                // 建筑名称
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 分类标签
                Text(template.category.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(template.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(template.category.color.opacity(0.15))
                    )

                // 建造时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(template.formattedBuildTime)
                        .font(.system(size: 11))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? template.category.color : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "1",
        templateId: "campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        description: "提供温暖和照明",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 300,
        maxPerTerritory: 3,
        maxLevel: 3
    )

    let sampleTemplate2 = BuildingTemplate(
        id: "2",
        templateId: "storage",
        name: "小仓库",
        category: .storage,
        tier: 1,
        description: "存储物资",
        icon: "archivebox.fill",
        requiredResources: ["wood": 40, "scrap_metal": 20],
        buildTimeSeconds: 480,
        maxPerTerritory: 2,
        maxLevel: 3
    )

    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            BuildingCard(template: sampleTemplate) {}
            BuildingCard(template: sampleTemplate2) {}
            SelectableBuildingCard(template: sampleTemplate, isSelected: true) {}
            SelectableBuildingCard(template: sampleTemplate2, isSelected: false) {}
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
