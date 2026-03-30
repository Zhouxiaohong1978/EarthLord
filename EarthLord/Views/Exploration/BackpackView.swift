//
//  BackpackView.swift
//  EarthLord
//
//  玩家背包管理页面
//  显示背包容量、物品列表，支持搜索和分类筛选
//

import SwiftUI

// MARK: - 物品分类配置

extension ItemCategory {
    /// 分类对应的图标
    var icon: String {
        switch self {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .weapon:
            return "hammer.fill"
        case .clothing:
            return "tshirt.fill"
        case .misc:
            return "archivebox.fill"
        }
    }

    /// 分类对应的颜色
    var color: Color {
        switch self {
        case .water:
            return .cyan
        case .food:
            return .orange
        case .medical:
            return .red
        case .material:
            return .brown
        case .tool:
            return .gray
        case .weapon:
            return .purple
        case .clothing:
            return .indigo
        case .misc:
            return ApocalypseTheme.textSecondary
        }
    }
}

// MARK: - 稀有度配置

extension ItemRarity {
    /// 稀有度对应的颜色
    var color: Color {
        switch self {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }
}

// MARK: - 品质配置

extension ItemQuality {
    /// 品质对应的颜色
    var color: Color {
        switch self {
        case .broken:
            return .red
        case .worn:
            return .orange
        case .normal:
            return .gray
        case .good:
            return .green
        case .excellent:
            return .cyan
        }
    }
}

// MARK: - 背包筛选类型

enum BackpackFilterType: CaseIterable, Identifiable {
    case all
    case food
    case water
    case material
    case tool
    case medical
    case weapon
    case clothing
    case misc

    var id: String { title }

    var title: String {
        switch self {
        case .all:      return "全部"
        case .food:     return ItemCategory.food.rawValue
        case .water:    return ItemCategory.water.rawValue
        case .material: return ItemCategory.material.rawValue
        case .tool:     return ItemCategory.tool.rawValue
        case .medical:  return ItemCategory.medical.rawValue
        case .weapon:   return ItemCategory.weapon.rawValue
        case .clothing: return ItemCategory.clothing.rawValue
        case .misc:     return ItemCategory.misc.rawValue
        }
    }

    var icon: String {
        switch self {
        case .all:      return "square.grid.2x2.fill"
        case .food:     return ItemCategory.food.icon
        case .water:    return ItemCategory.water.icon
        case .material: return ItemCategory.material.icon
        case .tool:     return ItemCategory.tool.icon
        case .medical:  return ItemCategory.medical.icon
        case .weapon:   return ItemCategory.weapon.icon
        case .clothing: return ItemCategory.clothing.icon
        case .misc:     return ItemCategory.misc.icon
        }
    }

    /// 转换为 ItemCategory
    var category: ItemCategory? {
        switch self {
        case .all:      return nil
        case .food:     return .food
        case .water:    return .water
        case .material: return .material
        case .tool:     return .tool
        case .medical:  return .medical
        case .weapon:   return .weapon
        case .clothing: return .clothing
        case .misc:     return .misc
        }
    }
}

// MARK: - 主视图

struct BackpackView: View {
    // MARK: - 状态

    /// 背包管理器
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 搜索文字
    @State private var searchText = ""

    /// 当前选中的筛选类型
    @State private var selectedFilter: BackpackFilterType = .all

    /// 动画显示的容量值
    @State private var animatedCapacity: Double = 0

    /// 列表动画ID（用于切换分类时刷新动画）
    @State private var listAnimationID = UUID()

    /// 是否首次加载
    @State private var isFirstLoad = false

    // MARK: - 容量配置

    private var maxCapacity: Double { Double(InventoryManager.shared.backpackCapacity) }

    /// 当前容量（从背包管理器获取）
    private var currentCapacity: Double {
        Double(inventoryManager.totalItemCount)
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        currentCapacity / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    // MARK: - 计算属性

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = inventoryManager.items

        // 分类筛选
        if let category = selectedFilter.category {
            items = items.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                    return false
                }
                return definition.category == category
            }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                    return false
                }
                return definition.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索和筛选
                searchAndFilter
                    .padding(.top, 16)

                // 物品列表或空状态
                if inventoryManager.isLoading && inventoryManager.items.isEmpty {
                    // 加载中且列表为空时显示骨架
                    loadingState
                } else if inventoryManager.items.isEmpty {
                    // 背包完全为空
                    emptyStateEmpty
                } else if filteredItems.isEmpty {
                    // 搜索/筛选无结果
                    emptyStateNoResult
                } else {
                    itemList
                        .padding(.top, 12)
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await inventoryManager.refreshInventory()
                    }
                } label: {
                    if inventoryManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                    }
                }
                .disabled(inventoryManager.isLoading)
            }
        }
        .onAppear {
            Task {
                await inventoryManager.refreshInventory()
                isFirstLoad = false
            }
            // 进度条动画
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedCapacity = currentCapacity
            }
        }
        .onChange(of: inventoryManager.items) { _ in
            // 物品变化时更新容量动画
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCapacity = currentCapacity
            }
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题和数值
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("背包容量")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                Text("\(Int(animatedCapacity)) / \(Int(maxCapacity))")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(capacityColor)
                    .contentTransition(.numericText())
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 8)

                    // 进度（使用动画值）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * (animatedCapacity / maxCapacity), height: 8)
                }
            }
            .frame(height: 8)

            // 警告文字
            if capacityPercentage > 0.9 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 搜索和筛选

    private var searchAndFilter: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .padding(.horizontal, 16)

            // 分类按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BackpackFilterType.allCases) { filter in
                        CategoryChip(
                            title: filter.title,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedFilter = filter
                                // 刷新列表动画ID，触发重新入场
                                listAnimationID = UUID()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                        BackpackItemCard(item: item, definition: definition, onUse: {
                            Task { @MainActor in
                                try? await PhysiqueManager.shared.useItem(item)
                            }
                        }, onDisassemble: {
                            Task { @MainActor in
                                try? await InventoryManager.shared.disassembleItem(item)
                            }
                        })
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                            .animation(
                                .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                                value: listAnimationID
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .id(listAnimationID)
        }
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("加载背包数据...")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空状态：背包为空

    private var emptyStateEmpty: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("背包空空如也")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("去探索收集物资吧")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - 空状态：搜索无结果

    private var emptyStateNoResult: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到相关物品")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试更换筛选条件或搜索关键词")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - 分类按钮组件

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 背包物品卡片组件

struct BackpackItemCard: View {
    let item: BackpackItem
    let definition: ItemDefinition
    var onUse: (() -> Void)? = nil
    var onDisassemble: (() -> Void)? = nil

    @State private var showDisassembleConfirm = false

    private var isAIItem: Bool { item.customName != nil }
    private var displayName: String { item.customName ?? definition.name }
    private var disassembleReturn: Int { max(1, Int(Double(item.quantity) * 0.6)) }
    private var disassembleReturnItemId: String {
        InventoryManager.classifyDisassembleMaterial(from: item.customName ?? "", description: item.customDescription, fallback: item.itemId)
    }
    private var disassembleReturnName: String {
        MockExplorationData.getItemDefinition(by: disassembleReturnItemId)?.name ?? disassembleReturnItemId
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            itemIcon

            // 物品信息
            itemInfo

            Spacer()

            // 操作按钮
            actionButtons
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isAIItem ? ApocalypseTheme.cardBackground.opacity(0.8) : ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isAIItem ? ApocalypseTheme.warning.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .confirmationDialog(
            "拆解 \(displayName)",
            isPresented: $showDisassembleConfirm,
            titleVisibility: .visible
        ) {
            Button("确认拆解（返还 \(disassembleReturnName)×\(disassembleReturn)）", role: .destructive) {
                onDisassemble?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将被分解为 \(disassembleReturnName)，回收率 60%")
        }
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(definition.category.color.opacity(isAIItem ? 0.3 : 0.2))
                .frame(width: 44, height: 44)

            Image(systemName: definition.category.icon)
                .font(.system(size: 18))
                .foregroundColor(definition.category.color)

            if isAIItem {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(ApocalypseTheme.warning)
                    .offset(x: 14, y: -14)
            }
        }
    }

    // MARK: - 物品信息

    private var itemInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：名称和数量
            HStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(item.quantity)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 第二行：基底材料（AI物品）或重量、品质、稀有度
            if isAIItem {
                HStack(spacing: 6) {
                    Text("基底：\(definition.name)")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(quality.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(quality.color.opacity(0.15)))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(quality.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(quality.color.opacity(0.15)))
                    }

                    rarityBadge
                }
            }
        }
    }

    // MARK: - 稀有度标签

    private var rarityBadge: some View {
        Text(definition.rarity.rawValue)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(definition.rarity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(definition.rarity.color.opacity(0.15))
            )
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 6) {
            if isAIItem {
                // AI 物品：拆解按钮
                Button {
                    showDisassembleConfirm = true
                } label: {
                    Text("拆解")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.warning)
                        )
                }
            } else if definition.category == .food || definition.category == .water || definition.category == .medical {
                // 标准物品：使用按钮
                Button {
                    onUse?()
                } label: {
                    Text(LanguageManager.shared.localizedString(for: "使用"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.primary)
                        )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}

#Preview("Backpack Item Card") {
    let item = MockExplorationData.backpackItems[0]
    let definition = MockExplorationData.getItemDefinition(by: item.itemId)!

    BackpackItemCard(item: item, definition: definition)
        .padding()
        .background(ApocalypseTheme.background)
}

#Preview("高容量警告") {
    // 展示容量超过90%的状态
    NavigationStack {
        BackpackView()
    }
}
