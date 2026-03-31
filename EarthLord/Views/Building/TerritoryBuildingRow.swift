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
    @State private var showSpeedupSheet = false

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
        .sheet(isPresented: $showSpeedupSheet) {
            BuildingSpeedupSheet(building: building)
        }
    }

    // MARK: - 子视图

    /// 建筑图标
    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill((template?.category.color ?? ApocalypseTheme.primary).opacity(0.2))
                .frame(width: 44, height: 44)

            BuildingIconView(
                iconName: template?.icon ?? "building.2.fill",
                size: 20,
                tintColor: template?.category.color ?? ApocalypseTheme.primary
            )
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
            HStack(spacing: 8) {
                // 加速按钮
                Button {
                    showSpeedupSheet = true
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(red: 0.95, green: 0.62, blue: 0.12))
                        .clipShape(Circle())
                }
                // 进度环
                CircularProgressView(progress: building.buildProgress)
                    .frame(width: 36, height: 36)
            }
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

// MARK: - BuildingSpeedupSheet

/// 建造加速弹窗
struct BuildingSpeedupSheet: View {
    let building: PlayerBuilding
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var speedupTokenCount: Int = 0
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var availableSpeedupTokens: Int {
        inventoryManager.items
            .filter { $0.itemId == "build_speedup" }
            .reduce(0) { $0 + $1.quantity }
    }

    private var maxSpeedupTokens: Int { min(availableSpeedupTokens, 5) }

    /// 预计减少的总秒数（每个加速令 -30 分钟）
    private var totalReductionSeconds: Int {
        speedupTokenCount * 1800
    }

    /// 格式化减少时间
    private var formattedReduction: String {
        let total = totalReductionSeconds
        if total == 0 { return "0分钟" }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)小时\(minutes)分钟" }
        if hours > 0 { return "\(hours)小时" }
        return "\(minutes)分钟"
    }

    /// 加速后预计完成时间
    private var previewCompletedAt: Date? {
        guard let completedAt = building.buildCompletedAt, totalReductionSeconds > 0 else {
            return building.buildCompletedAt
        }
        return max(Date(), completedAt - TimeInterval(totalReductionSeconds))
    }

    /// 剩余时间格式化
    private func formattedRemaining(from date: Date) -> String {
        let secs = max(0, date.timeIntervalSince(Date()))
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        let s = Int(secs) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── 当前进度卡片 ──
                        VStack(spacing: 8) {
                            CircularProgressView(progress: building.buildProgress)
                                .frame(width: 72, height: 72)
                            Text(building.buildingName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            if let completedAt = building.buildCompletedAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text("剩余 \(formattedRemaining(from: completedAt))")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ApocalypseTheme.cardBackground))

                        // ── 建造加速令 ──
                        speedupSection(
                            icon: "bolt.fill",
                            iconColor: Color(red: 0.95, green: 0.62, blue: 0.12),
                            title: "建造加速令",
                            subtitle: "每个缩短 30 分钟，最多 5 个",
                            available: availableSpeedupTokens,
                            maxCount: maxSpeedupTokens,
                            count: $speedupTokenCount
                        )

                        // ── 加速预览 ──
                        if totalReductionSeconds > 0 {
                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(ApocalypseTheme.success)
                                    Text("缩短 \(formattedReduction)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ApocalypseTheme.success)
                                }
                                if let preview = previewCompletedAt {
                                    Text("完成时间 → \(formattedRemaining(from: preview))")
                                        .font(.system(size: 13))
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.success.opacity(0.1)))
                        }

                        // ── 确认按钮 ──
                        Button {
                            Task { await applySpeedup() }
                        } label: {
                            Group {
                                if isApplying {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bolt.fill")
                                        Text(totalReductionSeconds > 0 ? "立即加速" : "请选择数量")
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(totalReductionSeconds > 0
                                          ? Color(red: 0.95, green: 0.62, blue: 0.12)
                                          : ApocalypseTheme.textMuted)
                            )
                        }
                        .disabled(totalReductionSeconds == 0 || isApplying)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("建造加速")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("加速失败", isPresented: $showError) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                Task { await InventoryManager.shared.refreshInventory() }
            }
        }
    }

    // MARK: - 加速项组件

    private func speedupSection(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        available: Int,
        maxCount: Int,
        count: Binding<Int>
    ) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 标题 + 说明
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("拥有 \(available) 个")
                    .font(.system(size: 11))
                    .foregroundColor(available > 0 ? ApocalypseTheme.success : ApocalypseTheme.danger)
            }

            Spacer()

            // 数量选择器
            if maxCount > 0 {
                HStack(spacing: 0) {
                    Button {
                        if count.wrappedValue > 0 { count.wrappedValue -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundColor(count.wrappedValue > 0 ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    }

                    Text("\(count.wrappedValue)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minWidth: 28)
                        .multilineTextAlignment(.center)

                    Button {
                        if count.wrappedValue < maxCount { count.wrappedValue += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundColor(count.wrappedValue < maxCount ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.background))
            } else {
                Text("无")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 96)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    // MARK: - 执行加速

    private func applySpeedup() async {
        isApplying = true
        do {
            try await BuildingManager.shared.applyBuildSpeedup(
                buildingId: building.id,
                tokenCount: speedupTokenCount
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isApplying = false
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
