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

    // MARK: - Sheet 状态
    @State private var showCollectSheet = false
    @State private var showSpeedupSheet = false
    @State private var showMaintenanceSheet = false
    @State private var showFortifySheet = false
    @State private var showCraftingView = false

    // MARK: - 定时器驱动的动态值（不用 .id() 重建 view，避免菜单闪退）
    @State private var buildProgress: Double = 0
    @State private var remainingTime: String = ""
    @State private var canCollectNow: Bool = false
    @State private var productionCountdown: String = ""
    @State private var abandonCountdown: String = ""   // 耐久归零后的废弃倒计时文字

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - 耐久视觉状态

    private var activeDurability: Int? {
        guard building.status == .active else { return nil }
        return BuildingManager.shared.computedDurability(for: building)
    }

    private var rowStrokeColor: Color {
        guard let d = activeDurability else { return ApocalypseTheme.textMuted.opacity(0.3) }
        if d == 0  { return ApocalypseTheme.danger.opacity(0.85) }
        if d < 30  { return ApocalypseTheme.warning.opacity(0.7) }
        return ApocalypseTheme.textMuted.opacity(0.3)
    }

    private var rowStrokeWidth: CGFloat {
        guard let d = activeDurability else { return 1 }
        return d == 0 ? 1.5 : 1
    }

    var body: some View {
        HStack(spacing: 12) {
            buildingIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template?.localizedName ?? building.buildingName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ApocalypseTheme.primary.opacity(0.15)))
                }
                statusInfo
            }

            Spacer()
            trailingContent
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground)
                if activeDurability == 0 {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.danger.opacity(0.06))
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(rowStrokeColor, lineWidth: rowStrokeWidth))
        .onAppear { refreshTimerValues() }
        .onReceive(timer) { _ in refreshTimerValues() }
        .sheet(isPresented: $showCollectSheet, onDismiss: { refreshTimerValues() }) {
            BuildingCollectSheet(building: building)
        }
        .sheet(isPresented: $showSpeedupSheet) {
            BuildingSpeedupSheet(building: building)
        }
        .sheet(isPresented: $showMaintenanceSheet) {
            BuildingMaintenanceSheet(building: building, template: template)
        }
        .sheet(isPresented: $showFortifySheet) {
            BuildingFortifySheet(building: building, template: template, onConfirm: onUpgrade)
        }
        .sheet(isPresented: $showCraftingView) {
            NavigationStack {
                CraftingView(buildingLevel: building.level, buildingTemplateId: building.templateId)
            }
            .presentationBackground(ApocalypseTheme.background)
        }
    }

    /// 定时更新动态值，不触发 view 重建
    private func refreshTimerValues() {
        // 从 BuildingManager 取最新副本（collect 后 lastProducedAt 已更新）
        let b = BuildingManager.shared.playerBuildings.first(where: { $0.id == building.id }) ?? building
        if b.status == .constructing || b.status == .upgrading {
            buildProgress = b.buildProgress
            remainingTime = b.formattedRemainingTime
        }
        if BuildingManager.shared.hasProduction(b) {
            canCollectNow = BuildingManager.shared.canCollect(b)
            if let secs = BuildingManager.shared.secondsUntilNextProduction(b) {
                let h = Int(secs) / 3600
                let m = (Int(secs) % 3600) / 60
                productionCountdown = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            } else {
                productionCountdown = ""
            }
        }
        // 废弃倒计时（耐久归零后3天缓冲）
        if let remaining = BuildingManager.shared.abandonGraceRemaining(for: building) {
            if remaining <= 0 {
                abandonCountdown = String(localized: "即将废弃")
            } else {
                let days = Int(remaining) / 86400
                let hours = (Int(remaining) % 86400) / 3600
                if days > 0 {
                    abandonCountdown = String(format: String(localized: "还有%d天%d小时，超时将废弃"), days, hours)
                } else {
                    let mins = (Int(remaining) % 3600) / 60
                    abandonCountdown = String(format: String(localized: "还有%d小时%d分，超时将废弃"), hours, mins)
                }
            }
        } else {
            abandonCountdown = ""
        }
    }

    // MARK: - 子视图

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

    @ViewBuilder
    private var statusInfo: some View {
        switch building.status {
        case .constructing, .upgrading:
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: building.status.icon).font(.system(size: 10))
                    Text(building.status.displayName).font(.system(size: 11))
                }
                .foregroundColor(building.status.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(building.status.color.opacity(0.15)))

                if !remainingTime.isEmpty {
                    Text(remainingTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

        case .active:
            let durability = BuildingManager.shared.computedDurability(for: building)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: durability > 0 ? building.status.icon : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(durability > 0 ? building.status.displayName : String(localized: "需要维护"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(durability > 0 ? building.status.color : ApocalypseTheme.danger)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill((durability > 0 ? building.status.color : ApocalypseTheme.danger).opacity(0.15)))

                    if BuildingManager.shared.hasProduction(building) {
                        if canCollectNow {
                            Text(String(localized: "可领取"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(ApocalypseTheme.success)
                        } else if !productionCountdown.isEmpty {
                            Text(productionCountdown)
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }
                DurabilityBar(durability: durability)

                // 废弃倒计时：耐久归零后显示，督促玩家维护
                if !abandonCountdown.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 10))
                        Text(abandonCountdown)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.danger)
                }
            }

        case .inactive, .damaged:
            HStack(spacing: 4) {
                Image(systemName: building.status.icon).font(.system(size: 10))
                Text(building.status.displayName).font(.system(size: 11))
            }
            .foregroundColor(building.status.color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(building.status.color.opacity(0.15)))
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if building.status == .constructing || building.status == .upgrading {
            HStack(spacing: 8) {
                Button { showSpeedupSheet = true } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(red: 0.95, green: 0.62, blue: 0.12))
                        .clipShape(Circle())
                }
                CircularProgressView(progress: buildProgress)
                    .frame(width: 36, height: 36)
            }
        } else if building.status == .active {
            HStack(spacing: 8) {
                if canCollectNow {
                    Button { showCollectSheet = true } label: {
                        Text(String(localized: "领取"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(ApocalypseTheme.success)
                            .cornerRadius(8)
                    }
                }
                if building.templateId == "workbench" || building.templateId == "food_factory" || building.templateId == "equipment_forge" || building.templateId == "fuel_depot" {
                    Button { showCraftingView = true } label: {
                        Text(building.templateId == "food_factory" ? String(localized: "加工") : String(localized: "合成"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(8)
                    }
                }
                // 燃料储备站：显示燃料量 + 存入按钮
                if building.templateId == "fuel_depot" {
                    let bm = BuildingManager.shared
                    let capacity = bm.fuelDepotCapacity(level: building.level)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(building.fuelStored)/\(capacity)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    let backpackFuel = InventoryManager.shared.items.filter { $0.itemId == "fuel" && $0.customName == nil }.reduce(0) { $0 + $1.quantity }
                    if backpackFuel > 0 && building.fuelStored < capacity {
                        Button {
                            Task { try? await bm.depositFuel(quantity: backpackFuel) }
                        } label: {
                            Text(String(localized: "存入"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                }
                // 需要电力的建筑：断电时显示提示
                if (building.templateId == "radio_station" || building.templateId == "equipment_forge") && !BuildingManager.shared.isPowered {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.slash.fill")
                            .font(.system(size: 10))
                        Text(String(localized: "断电"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.warning)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(ApocalypseTheme.warning.opacity(0.15)))
                }
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
            // 维护按钮
            Button {
                showMaintenanceSheet = true
            } label: {
                Label(String(localized: "维护"), systemImage: "wrench.fill")
            }

            Divider()

            // 强化按钮
            if let template = template, building.level >= template.maxLevel {
                Button {} label: {
                    Label(String(localized: "已达最高等级"), systemImage: "checkmark.circle.fill")
                }
                .disabled(true)
            } else {
                Button {
                    showFortifySheet = true
                } label: {
                    Label(String(localized: "强化"), systemImage: "arrow.up.circle")
                }
            }

            Divider()

            // 对外可见开关（显示当前状态，点击切换）
            Button {
                Task {
                    try? await BuildingManager.shared.toggleBuildingVisibility(buildingId: building.id)
                }
            } label: {
                if building.showToOthers {
                    Label(String(localized: "对外展示中（点击关闭）"), systemImage: "eye.fill")
                } else {
                    Label(String(localized: "未对外展示（点击开启）"), systemImage: "eye.slash")
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
                            Text(String(localized: "选择存放位置"))
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
                                Text(String(localized: "存入背包"))
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
                                Text(String(localized: "存入仓库"))
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
                            Text(String(localized: "建造小仓库后可使用此选项"))
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
            .navigationTitle(String(localized: "领取产出"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert(String(localized: "领取失败"), isPresented: .constant(errorMessage != nil)) {
                Button(String(localized: "确定")) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear {
                Task { await warehouseManager.refreshItems() }
            }
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

    private var localizedBuildingName: String {
        BuildingManager.shared.buildingTemplates
            .first(where: { $0.templateId == building.templateId })?
            .localizedName ?? building.buildingName
    }

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
                            Text(localizedBuildingName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            if let completedAt = building.buildCompletedAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text(String(format: String(localized: "剩余 %@"), formattedRemaining(from: completedAt)))
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
                                    Text(String(format: String(localized: "缩短 %@"), formattedReduction))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ApocalypseTheme.success)
                                }
                                if let preview = previewCompletedAt {
                                    Text(String(format: String(localized: "完成时间 → %@"), formattedRemaining(from: preview)))
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
            .navigationTitle(String(localized: "建造加速"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert(String(localized: "加速失败"), isPresented: $showError) {
                Button(String(localized: "确定")) { errorMessage = nil }
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
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
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

// MARK: - MaterialSourceRow

/// 材料需求行：分别显示背包和仓库来源，高亮被调用的仓库
private struct MaterialSourceRow: View {
    let itemId: String
    let required: Int
    let backpackCount: Int
    let warehouseCount: Int

    private var total: Int { backpackCount + warehouseCount }
    private var sufficient: Bool { total >= required }
    /// 背包不够，仓库需要介入
    private var usesWarehouse: Bool { backpackCount < required }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // 状态图标
                Image(systemName: sufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(sufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)

                // 物品名称
                Text(LocalizedStringKey(itemId))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 来源数量区域
                HStack(spacing: 4) {
                    // 背包数量徽章
                    sourceBadge(
                        icon: "bag.fill",
                        count: backpackCount,
                        active: backpackCount > 0,
                        highlighted: false
                    )

                    // 仓库数量：仅在仓库有货或背包不足时显示
                    if usesWarehouse || warehouseCount > 0 {
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        sourceBadge(
                            icon: "archivebox.fill",
                            count: warehouseCount,
                            active: warehouseCount > 0,
                            highlighted: usesWarehouse && warehouseCount > 0
                        )
                    }

                    Text("/ \(required)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.leading, 2)
                }
            }

            // 不足时显示差额提示
            if !sufficient {
                HStack {
                    Spacer()
                    Text(String(format: String(localized: "还差 %d"), required - total))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(ApocalypseTheme.danger.opacity(0.12)))
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func sourceBadge(icon: String, count: Int, active: Bool, highlighted: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(
            highlighted ? ApocalypseTheme.info :
            active      ? ApocalypseTheme.textSecondary :
                          ApocalypseTheme.textMuted
        )
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(
            Capsule().fill(
                highlighted ? ApocalypseTheme.info.opacity(0.15) :
                              Color.white.opacity(0.06)
            )
        )
    }
}

// MARK: - DurabilityBar

/// 耐久度进度条（嵌入建筑行）
private struct DurabilityBar: View {
    let durability: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 9))
                .foregroundColor(barColor)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(max(0, durability)) / 100.0, height: 4)
                }
            }
            .frame(height: 4)
            Text("\(durability)%")
                .font(.system(size: 10))
                .foregroundColor(barColor)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if durability >= 60 { return ApocalypseTheme.success }
        if durability > 0   { return ApocalypseTheme.warning }
        return ApocalypseTheme.danger
    }
}

// MARK: - BuildingMaintenanceSheet

/// 建筑维护弹窗 - 显示所需材料并执行维护
struct BuildingMaintenanceSheet: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var warehouseManager = WarehouseManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var manager: BuildingManager { BuildingManager.shared }

    private var cost: [String: Int] {
        guard let t = template else { return [:] }
        return manager.maintenanceCost(for: t)
    }

    private var durability: Int { manager.computedDurability(for: building) }

    private var backpackCounts: [String: Int] {
        var result: [String: Int] = [:]
        for item in inventoryManager.items where item.customName == nil {
            result[item.itemId, default: 0] += item.quantity
        }
        return result
    }

    private var warehouseCounts: [String: Int] {
        var result: [String: Int] = [:]
        for item in warehouseManager.items where item.customName == nil {
            result[item.itemId, default: 0] += item.quantity
        }
        return result
    }

    private var canMaintain: Bool {
        cost.allSatisfy { (itemId, required) in
            (backpackCounts[itemId] ?? 0) + (warehouseCounts[itemId] ?? 0) >= required
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // 耐久状态卡片
                        durabilityCard

                        // 所需材料列表
                        materialsCard

                        // 维护说明
                        maintenanceNote

                        // 确认按钮
                        confirmButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(String(localized: "建筑维护"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert(String(localized: "维护失败"), isPresented: .constant(errorMessage != nil)) {
                Button(String(localized: "确定")) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear {
                Task {
                    await inventoryManager.refreshInventory()
                    await warehouseManager.refreshItems()
                }
            }
        }
    }

    // MARK: - 子视图

    private var durabilityCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((template?.category.color ?? ApocalypseTheme.primary).opacity(0.15))
                        .frame(width: 52, height: 52)
                    BuildingIconView(
                        iconName: template?.icon ?? "building.2.fill",
                        size: 22,
                        tintColor: template?.category.color ?? ApocalypseTheme.primary
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(template?.localizedName ?? building.buildingName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(String(format: String(localized: "Lv.%d · 当前耐久 %d%%"), building.level, durability))
                        .font(.system(size: 13))
                        .foregroundColor(durabilityColor)
                }
                Spacer()
            }

            // 耐久度进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(durabilityColor)
                        .frame(width: geo.size.width * CGFloat(max(0, durability)) / 100.0, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: durability)
                }
            }
            .frame(height: 8)

            let isCampfire = building.templateId == "campfire"
            let maxDurability = manager.maintenanceMaxDurability(territoryId: building.territoryId, templateId: building.templateId)
            let hasWorkshop = maxDurability == 100
            HStack {
                Text(String(localized: "维护后恢复至"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Spacer()
                if !isCampfire {
                    if hasWorkshop {
                        HStack(spacing: 3) {
                            Image(systemName: "wrench.fill")
                                .font(.system(size: 9))
                            Text(String(localized: "维修工坊 +50% 寿命"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ApocalypseTheme.success.opacity(0.15)))
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "wrench.slash.fill")
                                .font(.system(size: 9))
                            Text(String(localized: "无维修工坊"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ApocalypseTheme.warning.opacity(0.15)))
                    }
                }
                Text("\(maxDurability)%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isCampfire ? ApocalypseTheme.success : (hasWorkshop ? ApocalypseTheme.success : ApocalypseTheme.warning))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    private var materialsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "所需材料"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            if cost.isEmpty {
                Text(String(localized: "无需材料"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                ForEach(cost.sorted(by: { $0.key < $1.key }), id: \.key) { itemId, required in
                    MaterialSourceRow(
                        itemId: itemId,
                        required: required,
                        backpackCount: backpackCounts[itemId] ?? 0,
                        warehouseCount: warehouseCounts[itemId] ?? 0
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    private var maintenanceNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.info)
            Text(building.templateId == "campfire"
                 ? String(localized: "篝火约 7 天耐久归零，维护后重置计时")
                 : String(localized: "建筑约 30 天耐久归零，等级越高衰减越慢"))
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }

    private var confirmButton: some View {
        Button {
            Task { await doMaintain() }
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.fill")
                        Text(canMaintain ? String(localized: "确认维护") : String(localized: "材料不足"))
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canMaintain ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canMaintain || isLoading)
    }

    private var durabilityColor: Color {
        if durability >= 60 { return ApocalypseTheme.success }
        if durability > 0   { return ApocalypseTheme.warning }
        return ApocalypseTheme.danger
    }

    private func doMaintain() async {
        isLoading = true
        do {
            try await BuildingManager.shared.maintainBuilding(buildingId: building.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - BuildingFortifySheet

/// 建筑强化确认弹窗 - 显示升级所需材料并执行强化
struct BuildingFortifySheet: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var onConfirm: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var warehouseManager = WarehouseManager.shared

    /// 原始升级材料
    private var originalCost: [String: Int] {
        guard let t = template,
              let upgradeResources = t.upgradeResources,
              building.level - 1 < upgradeResources.count else { return [:] }
        return upgradeResources[building.level - 1]
    }

    /// 是否有维修工坊（固定 20% 折扣）
    private var hasRepairWorkshop: Bool {
        BuildingManager.shared.repairWorkshopDiscount(for: building.territoryId) > 0
    }

    /// 折扣后实际升级材料
    private var cost: [String: Int] {
        BuildingManager.shared.discountedUpgradeCost(originalCost, territoryId: building.territoryId)
    }

    private var backpackCounts: [String: Int] {
        var result: [String: Int] = [:]
        for item in inventoryManager.items where item.customName == nil {
            result[item.itemId, default: 0] += item.quantity
        }
        return result
    }

    private var warehouseCounts: [String: Int] {
        var result: [String: Int] = [:]
        for item in warehouseManager.items where item.customName == nil {
            result[item.itemId, default: 0] += item.quantity
        }
        return result
    }

    private var canFortify: Bool {
        cost.allSatisfy { (itemId, required) in
            (backpackCounts[itemId] ?? 0) + (warehouseCounts[itemId] ?? 0) >= required
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // 等级升级卡片
                        levelCard

                        // 所需材料列表
                        materialsCard

                        // 强化说明
                        fortifyNote

                        // 确认按钮
                        confirmButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(String(localized: "建筑强化"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear {
                Task {
                    await inventoryManager.refreshInventory()
                    await warehouseManager.refreshItems()
                }
            }
        }
    }

    // MARK: - 子视图

    private var levelCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((template?.category.color ?? ApocalypseTheme.primary).opacity(0.15))
                    .frame(width: 56, height: 56)
                BuildingIconView(
                    iconName: template?.icon ?? "building.2.fill",
                    size: 24,
                    tintColor: template?.category.color ?? ApocalypseTheme.primary
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(template?.localizedName ?? building.buildingName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    levelBadge(level: building.level, color: ApocalypseTheme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                    levelBadge(level: building.level + 1, color: ApocalypseTheme.primary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    private func levelBadge(level: Int, color: Color) -> some View {
        Text("Lv.\(level)")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private var materialsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(String(localized: "所需材料"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if hasRepairWorkshop {
                    HStack(spacing: 3) {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 9))
                        Text(String(localized: "维修工坊 -20%"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ApocalypseTheme.success.opacity(0.15)))
                }
            }

            if cost.isEmpty {
                Text(String(localized: "无材料要求"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                ForEach(cost.sorted(by: { $0.key < $1.key }), id: \.key) { itemId, required in
                    MaterialSourceRow(
                        itemId: itemId,
                        required: required,
                        backpackCount: backpackCounts[itemId] ?? 0,
                        warehouseCount: warehouseCounts[itemId] ?? 0
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    private var fortifyNote: some View {
        let mgr = BuildingManager.shared
        let tid = building.templateId
        let curLevel = building.level
        let newLevel = curLevel + 1

        let curDays   = mgr.durabilityLifeDays(templateId: tid, level: curLevel, territoryId: building.territoryId)
        let newDays   = mgr.durabilityLifeDays(templateId: tid, level: newLevel, territoryId: building.territoryId)
        let durPct    = Int(((newDays - curDays) / curDays * 100).rounded())

        let curVital  = mgr.vitalDecayAmount(templateId: tid, level: curLevel)
        let newVital  = mgr.vitalDecayAmount(templateId: tid, level: newLevel)
        let hasVital  = newVital > 0

        return VStack(spacing: 10) {
            // ── 对比卡片 ──
            VStack(spacing: 0) {
                // 耐久时限行
                fortifyCompareRow(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: ApocalypseTheme.warning,
                    label: String(localized: "耐久时限"),
                    before: formatDays(curDays),
                    after: formatDays(newDays),
                    badge: "+\(durPct)%"
                )

                if hasVital {
                    Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                    // 体征减缓行
                    fortifyCompareRow(
                        icon: "heart.fill",
                        iconColor: ApocalypseTheme.danger,
                        label: String(localized: "体征减缓"),
                        before: "-\(Int((curVital * 100).rounded()))%",
                        after:  "-\(Int((newVital * 100).rounded()))%",
                        badge:  "+\(Int(((newVital - curVital) * 100).rounded()))%"
                    )
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))

            // 逐级提示
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.info)
                Text(String(localized: "强化逐级进行：Lv1 → Lv2 → Lv3，背包优先扣除，不足从仓库补"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 4)
        }
    }

    private func fortifyCompareRow(
        icon: String, iconColor: Color,
        label: String, before: String, after: String, badge: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(before)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
            Text(after)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ApocalypseTheme.success)
            Text(badge)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.success)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(ApocalypseTheme.success.opacity(0.15)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func formatDays(_ days: Double) -> String {
        if days < 1 { return String(format: "%.0f", days * 24) + String(localized: "小时") }
        let d = Int(days)
        let h = Int((days - Double(d)) * 24)
        if h > 0 { return "\(d)" + String(localized: "天") + "\(h)" + String(localized: "小时") }
        return "\(d)" + String(localized: "天")
    }

    private var confirmButton: some View {
        Button {
            dismiss()
            onConfirm?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                Text(canFortify ? String(localized: "确认强化") : String(localized: "材料不足"))
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canFortify ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canFortify)
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
        mapIconSize: nil,
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
        updatedAt: Date(),
        durability: 65
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
        updatedAt: Date(),
        durability: 100
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
