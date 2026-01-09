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

    var id: String { title }

    var title: String {
        switch self {
        case .all: return "全部"
        case .food: return "食物"
        case .water: return "水"
        case .material: return "材料"
        case .tool: return "工具"
        case .medical: return "医疗"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .medical: return "cross.case.fill"
        }
    }

    /// 转换为 ItemCategory
    var category: ItemCategory? {
        switch self {
        case .all: return nil
        case .food: return .food
        case .water: return .water
        case .material: return .material
        case .tool: return .tool
        case .medical: return .medical
        }
    }
}

// MARK: - 主视图

struct BackpackView: View {
    // MARK: - 状态

    /// 搜索文字
    @State private var searchText = ""

    /// 当前选中的筛选类型
    @State private var selectedFilter: BackpackFilterType = .all

    /// 动画显示的容量值
    @State private var animatedCapacity: Double = 0

    /// 列表动画ID（用于切换分类时刷新动画）
    @State private var listAnimationID = UUID()

    // MARK: - 容量配置（假数据）

    private let currentCapacity: Double = 64
    private let maxCapacity: Double = 100

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
        var items = MockExplorationData.backpackItems

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
                if MockExplorationData.backpackItems.isEmpty {
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
        .onAppear {
            // 进度条动画
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
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
                        BackpackItemCard(item: item, definition: definition)
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
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(definition.category.color.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: definition.category.icon)
                .font(.system(size: 18))
                .foregroundColor(definition.category.color)
        }
    }

    // MARK: - 物品信息

    private var itemInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：名称和数量
            HStack(spacing: 6) {
                Text(definition.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(item.quantity)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 第二行：重量、品质、稀有度
            HStack(spacing: 8) {
                // 重量
                Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 品质（如有）
                if let quality = item.quality {
                    Text(quality.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(quality.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(quality.color.opacity(0.15))
                        )
                }

                // 稀有度标签
                rarityBadge
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
            // 使用按钮
            Button {
                print("使用物品: \(definition.name)")
            } label: {
                Text("使用")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.primary)
                    )
            }

            // 存储按钮
            Button {
                print("存储物品: \(definition.name)")
            } label: {
                Text("存储")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 48, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                    )
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
