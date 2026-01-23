//
//  BuildingDetailView.swift
//  EarthLord
//
//  建筑详情页 - 显示完整建筑信息和开始建造入口
//

import SwiftUI

/// 建筑详情视图
struct BuildingDetailView: View {
    let template: BuildingTemplate
    var onDismiss: () -> Void
    var onStartConstruction: (BuildingTemplate) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑头部信息
                    headerSection

                    // 描述
                    descriptionSection

                    // 所需资源
                    resourcesSection

                    // 建筑属性
                    attributesSection

                    Spacer(minLength: 20)

                    // 开始建造按钮
                    startButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - 子视图

    /// 头部信息
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 大图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: template.icon)
                    .font(.system(size: 48))
                    .foregroundColor(template.category.color)
            }

            // 分类标签
            HStack(spacing: 8) {
                Image(systemName: template.category.icon)
                    .font(.system(size: 12))
                Text(template.category.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(template.category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(template.category.color.opacity(0.15))
            )

            // 等级信息
            Text(String(format: String(localized: "T%d 建筑 · 最高 Lv.%d"), template.tier, template.maxLevel))
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 描述区域
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "描述"))

            Text(template.description)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 所需资源区域
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "建造所需"))

            VStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    if let amount = template.requiredResources[resourceId] {
                        SimpleResourceRow(
                            resourceName: resourceDisplayName(for: resourceId),
                            amount: amount,
                            icon: resourceIcon(for: resourceId)
                        )
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 建筑属性区域
    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "建筑属性"))

            VStack(spacing: 0) {
                attributeRow(
                    icon: "clock",
                    title: String(localized: "建造时间"),
                    value: template.formattedBuildTime
                )

                Divider()
                    .background(ApocalypseTheme.textMuted)

                attributeRow(
                    icon: "number",
                    title: String(localized: "领地上限"),
                    value: String(format: String(localized: "%d 个"), template.maxPerTerritory)
                )

                Divider()
                    .background(ApocalypseTheme.textMuted)

                attributeRow(
                    icon: "arrow.up.circle",
                    title: String(localized: "最高等级"),
                    value: "Lv.\(template.maxLevel)"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 开始建造按钮
    private var startButton: some View {
        Button {
            onStartConstruction(template)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                Text(String(localized: "开始建造"))
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助方法

    /// 区域标题
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ApocalypseTheme.textPrimary)
    }

    /// 属性行
    private func attributeRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        description: "篝火是最基本的生存设施，提供温暖和照明。在寒冷的夜晚，篝火可以帮助你抵御低温，同时也能驱赶野兽。",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 300,
        maxPerTerritory: 3,
        maxLevel: 3
    )

    BuildingDetailView(
        template: sampleTemplate,
        onDismiss: {},
        onStartConstruction: { _ in }
    )
}
