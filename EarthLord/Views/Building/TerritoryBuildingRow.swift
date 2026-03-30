//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件 - 显示建筑状态、进度和操作菜单
//

import SwiftUI
import Combine

/// 领地建筑行
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var onUpgrade: (() -> Void)?
    var onDemolish: (() -> Void)?

    /// 定时器触发器 - 用于实时更新建造进度和产出倒计时
    @State private var timerTrigger = false
    @State private var showCollectSheet = false

    /// 定时器
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            buildingIcon

            // 中间：名称 + 状态
            VStack(alignment: .leading, spacing: 4) {
                // 名称 + 等级
                HStack(spacing: 6) {
                    Text(template?.localizedName ?? building.buildingName)
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
        .onReceive(timer) { _ in
            if building.status == .constructing || building.status == .upgrading
                || BuildingManager.shared.hasProduction(building) {
                timerTrigger.toggle()
            }
        }
        .id(timerTrigger) // 通过改变 id 强制视图刷新
        .sheet(isPresented: $showCollectSheet) {
            BuildingCollectSheet(building: building)
        }
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
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: building.status.icon)
                        .font(.system(size: 10))
                    Text(building.status.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(building.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(building.status.color.opacity(0.15)))

                // 产出倒计时
                if BuildingManager.shared.hasProduction(building) {
                    if BuildingManager.shared.canCollect(building) {
                        Text("可领取")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)
                    } else if let secs = BuildingManager.shared.secondsUntilNextProduction(building) {
                        let h = Int(secs) / 3600
                        let m = (Int(secs) % 3600) / 60
                        Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }

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
            HStack(spacing: 8) {
                // 产出可领取时显示领取按钮
                if BuildingManager.shared.canCollect(building) {
                    Button {
                        showCollectSheet = true
                    } label: {
                        Text("领取")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ApocalypseTheme.success)
                            .cornerRadius(8)
                    }
                }
                // 操作菜单
                operationMenu
            }
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
    var foregroundColor: Color = ApocalypseTheme.success

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

// MARK: - BuildingCollectSheet

/// 建筑产出领取弹窗
struct BuildingCollectSheet: View {
    let building: PlayerBuilding
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var warehouseManager = WarehouseManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var config: (itemId: String, quantity: Int, intervalHours: Double)? {
        BuildingManager.shared.productionConfig(for: building.templateId)
    }

    private var itemDefinition: ItemDefinition? {
        guard let c = config else { return nil }
        return MockExplorationData.getItemDefinition(by: c.itemId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()
                VStack(spacing: 32) {
                    // 物品展示
                    if let def = itemDefinition, let c = config {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(def.category.color.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: def.category.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(def.category.color)
                            }
                            Text(LanguageManager.shared.localizedString(for: def.name))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Text("x\(c.quantity)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(ApocalypseTheme.success)
                            Text("选择存放位置")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }

                    // 两个选项按钮
                    VStack(spacing: 12) {
                        // 存入背包
                        Button {
                            Task { await collect(toWarehouse: false) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 16))
                                Text("存入背包")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)

                        // 存入仓库
                        Button {
                            Task { await collect(toWarehouse: true) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 16))
                                Text("存入仓库")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(warehouseManager.hasWarehouse ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(warehouseManager.hasWarehouse ? ApocalypseTheme.primary : ApocalypseTheme.textMuted, lineWidth: 1.5)
                            )
                        }
                        .disabled(isLoading || !warehouseManager.hasWarehouse)

                        if !warehouseManager.hasWarehouse {
                            Text("建造小仓库后可使用此选项")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 32)

                    if isLoading {
                        ProgressView().tint(ApocalypseTheme.primary)
                    }

                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationTitle("领取产出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("领取失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func collect(toWarehouse: Bool) async {
        isLoading = true
        do {
            try await BuildingManager.shared.collectProduction(
                buildingId: building.id,
                toWarehouse: toWarehouse
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "1",
        templateId: "campfire",
        name: "篝火",
        nameEn: "Campfire",
        category: .survival,
        tier: 1,
        description: "提供温暖和照明",
        descriptionEn: "Provides warmth and light.",
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
