//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件 - 显示建筑状态、进度和操作菜单
//

import SwiftUI

/// 领地建筑行
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var onUpgrade: (() -> Void)?
    var onDemolish: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            buildingIcon

            // 中间：名称 + 状态
            VStack(alignment: .leading, spacing: 4) {
                // 名称 + 等级
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary.opacity(0.15))
                        )
                }

                // 状态信息
                statusInfo
            }

            Spacer()

            // 右侧：操作菜单或进度环
            trailingContent
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 子视图

    /// 建筑图标
    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill((template?.category.color ?? ApocalypseTheme.primary).opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: template?.icon ?? "building.2")
                .font(.system(size: 20))
                .foregroundColor(template?.category.color ?? ApocalypseTheme.primary)
        }
    }

    /// 状态信息
    @ViewBuilder
    private var statusInfo: some View {
        switch building.status {
        case .constructing, .upgrading:
            HStack(spacing: 6) {
                // 状态徽章
                HStack(spacing: 4) {
                    Image(systemName: building.status.icon)
                        .font(.system(size: 10))
                    Text(building.status.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(building.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(building.status.color.opacity(0.15))
                )

                // 剩余时间
                if !building.formattedRemainingTime.isEmpty {
                    Text(building.formattedRemainingTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

        case .active:
            HStack(spacing: 4) {
                Image(systemName: building.status.icon)
                    .font(.system(size: 10))
                Text(building.status.displayName)
                    .font(.system(size: 11))
            }
            .foregroundColor(building.status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(building.status.color.opacity(0.15))
            )

        case .inactive, .damaged:
            HStack(spacing: 4) {
                Image(systemName: building.status.icon)
                    .font(.system(size: 10))
                Text(building.status.displayName)
                    .font(.system(size: 11))
            }
            .foregroundColor(building.status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(building.status.color.opacity(0.15))
            )
        }
    }

    /// 右侧内容
    @ViewBuilder
    private var trailingContent: some View {
        if building.status == .constructing || building.status == .upgrading {
            // 进度环
            CircularProgressView(progress: building.buildProgress)
                .frame(width: 36, height: 36)
        } else if building.status == .active {
            // 操作菜单
            operationMenu
        } else {
            // 其他状态：显示状态图标
            Image(systemName: building.status.icon)
                .font(.system(size: 20))
                .foregroundColor(building.status.color)
        }
    }

    /// 操作菜单
    private var operationMenu: some View {
        Menu {
            // 升级按钮
            if let template = template, building.level >= template.maxLevel {
                Button {} label: {
                    Label(String(localized: "已达最高等级"), systemImage: "checkmark.circle.fill")
                }
                .disabled(true)
            } else {
                Button {
                    onUpgrade?()
                } label: {
                    Label(String(localized: "升级"), systemImage: "arrow.up.circle")
                }
            }

            Divider()

            // 拆除按钮
            Button(role: .destructive) {
                onDemolish?()
            } label: {
                Label(String(localized: "拆除"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundColor(ApocalypseTheme.primary)
        }
    }
}

// MARK: - 圆形进度条

/// 圆形进度条视图
struct CircularProgressView: View {
    let progress: Double
    var lineWidth: CGFloat = 4
    var backgroundColor: Color = ApocalypseTheme.textMuted.opacity(0.3)
    var foregroundColor: Color = ApocalypseTheme.primary

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // 进度圆环
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(foregroundColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // 进度文字
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
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

    let activeBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "篝火",
        status: .active,
        level: 2,
        locationLat: 31.23,
        locationLon: 121.47,
        buildStartedAt: Date().addingTimeInterval(-300),
        buildCompletedAt: Date(),
        createdAt: Date(),
        updatedAt: Date()
    )

    let constructingBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "篝火",
        status: .constructing,
        level: 1,
        locationLat: 31.23,
        locationLon: 121.47,
        buildStartedAt: Date().addingTimeInterval(-150),
        buildCompletedAt: Date().addingTimeInterval(150),
        createdAt: Date(),
        updatedAt: Date()
    )

    VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: activeBuilding,
            template: sampleTemplate,
            onUpgrade: {},
            onDemolish: {}
        )

        TerritoryBuildingRow(
            building: constructingBuilding,
            template: sampleTemplate
        )

        // 进度条预览
        HStack(spacing: 20) {
            CircularProgressView(progress: 0.25)
                .frame(width: 50, height: 50)
            CircularProgressView(progress: 0.5)
                .frame(width: 50, height: 50)
            CircularProgressView(progress: 0.75)
                .frame(width: 50, height: 50)
            CircularProgressView(progress: 1.0)
                .frame(width: 50, height: 50)
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
