//
//  ItemPickerSheet.swift
//  EarthLord
//
//  物品选择器弹窗
//  用于选择出售/求购物品
//

import SwiftUI

/// 物品选择器模式
enum ItemPickerMode {
    case fromInventory    // 从库存选择（出售）
    case fromAllItems     // 从全部物品选择（求购）
}

/// 可选物品模型
struct SelectableItem: Identifiable {
    let id: String
    let definition: ItemDefinition
    let availableQuantity: Int?  // 库存数量（仅库存模式）
    let quality: ItemQuality?
    let customName: String?      // AI 命名物品

    init(id: String, definition: ItemDefinition, availableQuantity: Int?, quality: ItemQuality?, customName: String? = nil) {
        self.id = id
        self.definition = definition
        self.availableQuantity = availableQuantity
        self.quality = quality
        self.customName = customName
    }

    /// UI 展示名称
    var displayName: String { customName ?? definition.name }
}

struct ItemPickerSheet: View {
    let mode: ItemPickerMode
    let onSelect: ([TradeItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory?
    @State private var showAIOnly = false          // 仅显示特殊物品
    @State private var selectedItems: [TradeItem] = []
    @State private var showQuantityPicker = false
    @State private var pendingItem: SelectableItem?
    @State private var pendingQuantity = 1

    /// 可选物品列表（按 itemId 合并，避免同种物品因品质不同显示多行）
    private var selectableItems: [SelectableItem] {
        switch mode {
        case .fromInventory:
            // 标准物品：按 itemId 分组，数量加总
            var grouped: [String: Int] = [:]
            for item in inventoryManager.items where item.customName == nil {
                grouped[item.itemId, default: 0] += item.quantity
            }
            var result: [SelectableItem] = grouped.compactMap { itemId, totalQty in
                guard let definition = MockExplorationData.getItemDefinition(by: itemId) else { return nil }
                return SelectableItem(id: itemId, definition: definition, availableQuantity: totalQty, quality: nil)
            }
            // AI 命名物品：每条记录单独展示
            let aiItems: [SelectableItem] = inventoryManager.items.compactMap { item in
                guard item.customName != nil,
                      let definition = MockExplorationData.getItemDefinition(by: item.itemId) else { return nil }
                return SelectableItem(
                    id: item.id.uuidString,
                    definition: definition,
                    availableQuantity: item.quantity,
                    quality: item.quality,
                    customName: item.customName
                )
            }
            result.append(contentsOf: aiItems)
            return result.sorted { $0.displayName < $1.displayName }

        case .fromAllItems:
            return MockExplorationData.itemDefinitions.map { definition in
                SelectableItem(
                    id: definition.id,
                    definition: definition,
                    availableQuantity: nil,
                    quality: nil
                )
            }
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [SelectableItem] {
        var items = selectableItems

        // 特殊物品筛选
        if showAIOnly {
            items = items.filter { $0.customName != nil }
        } else if let category = selectedCategory {
            // 分类筛选：排除特殊物品，只显示普通物品
            items = items.filter { $0.customName == nil && $0.definition.category == category }
        } else {
            // 全部：普通物品全显示，特殊物品也显示（不过滤）
        }

        // 搜索筛选（同时搜索物品名和 AI 命名）
        if !searchText.isEmpty {
            items = items.filter {
                $0.definition.name.localizedCaseInsensitiveContains(searchText)
                || ($0.customName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表
                    itemList
                        .padding(.top, 12)

                    // 已选物品预览
                    if !selectedItems.isEmpty {
                        selectedItemsPreview
                    }
                }
            }
            .navigationTitle(mode == .fromInventory ? "选择出售物品" : "选择求购物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onSelect(selectedItems)
                        dismiss()
                    }
                    .foregroundColor(selectedItems.isEmpty ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    .disabled(selectedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showQuantityPicker) {
                quantityPickerSheet
            }
            .onAppear {
                // 出售模式：打开时刷新背包数据
                if mode == .fromInventory {
                    Task { await InventoryManager.shared.refreshInventory() }
                }
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
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
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                CategoryChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil && !showAIOnly
                ) {
                    selectedCategory = nil
                    showAIOnly = false
                }

                // 特殊物品（AI 命名）—— 仅出售模式（从背包选）才有 AI 物品
                if mode == .fromInventory {
                    CategoryChip(
                        title: "特殊物品",
                        icon: "sparkles",
                        isSelected: showAIOnly
                    ) {
                        showAIOnly = true
                        selectedCategory = nil
                    }
                }

                // 各分类
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: !showAIOnly && selectedCategory == category
                    ) {
                        selectedCategory = category
                        showAIOnly = false
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredItems) { item in
                    selectableItemRow(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, selectedItems.isEmpty ? 20 : 100)
        }
    }

    // MARK: - 可选物品行

    private func selectableItemRow(_ item: SelectableItem) -> some View {
        // AI 物品用 customName 匹配，标准物品用 definition.id 匹配
        let isSelected: Bool = item.customName != nil
            ? selectedItems.contains { $0.customName == item.customName && $0.itemId == item.definition.id }
            : selectedItems.contains { $0.customName == nil && $0.itemId == item.definition.id }

        return Button {
            if isSelected {
                // 取消选择
                if item.customName != nil {
                    selectedItems.removeAll { $0.customName == item.customName && $0.itemId == item.definition.id }
                } else {
                    selectedItems.removeAll { $0.customName == nil && $0.itemId == item.definition.id }
                }
            } else {
                // 选择物品，弹出数量选择
                pendingItem = item
                pendingQuantity = 1
                showQuantityPicker = true
            }
        } label: {
            HStack(spacing: 12) {
                // 物品图标
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(item.customName != nil
                              ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.2)
                              : item.definition.category.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    item.customName != nil
                                        ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6)
                                        : Color.clear,
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: item.definition.category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(item.customName != nil
                                         ? Color(red: 1.0, green: 0.84, blue: 0.0)
                                         : item.definition.category.color)

                    // AI 物品徽标
                    if item.customName != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .offset(x: 2, y: -2)
                    }
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 6) {
                        if let quantity = item.availableQuantity {
                            Text("库存: \(quantity)")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Text(item.definition.rarity.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(item.definition.rarity.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(item.definition.rarity.color.opacity(0.15))
                            )
                    }
                }

                Spacer()

                // 选中状态
                if isSelected {
                    let selectedMatch: TradeItem? = item.customName != nil
                        ? selectedItems.first { $0.customName == item.customName && $0.itemId == item.definition.id }
                        : selectedItems.first { $0.customName == nil && $0.itemId == item.definition.id }
                    if let selected = selectedMatch {
                        Text("x\(selected.quantity)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? ApocalypseTheme.success.opacity(0.1) : ApocalypseTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 已选物品预览

    private var selectedItemsPreview: some View {
        VStack(spacing: 8) {
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            HStack {
                Text("已选 \(selectedItems.count) 件物品")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 清空按钮
                Button {
                    selectedItems.removeAll()
                } label: {
                    Text("清空")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedItems) { item in
                        selectedItemChip(item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 已选物品标签

    private func selectedItemChip(_ item: TradeItem) -> some View {
        HStack(spacing: 4) {
            Text(item.itemName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("x\(item.quantity)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)

            Button {
                selectedItems.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 数量选择弹窗

    private var quantityPickerSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    if let item = pendingItem {
                        // 物品信息
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(item.definition.category.color.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: item.definition.category.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(item.definition.category.color)
                            }

                            Text(item.displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            if let available = item.availableQuantity {
                                Text("可用: \(available)")
                                    .font(.system(size: 14))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }

                        // 数量选择
                        VStack(spacing: 12) {
                            Text("选择数量")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            QuantityStepperView(
                                value: $pendingQuantity,
                                min: 1,
                                max: item.availableQuantity ?? 99
                            )
                        }

                        Spacer()

                        // 确认按钮
                        Button {
                            let tradeItem = TradeItem(
                                itemId: item.definition.id,   // 始终用 definition.id，customName 区分 AI 物品
                                quantity: pendingQuantity,
                                quality: item.quality,
                                customName: item.customName
                            )
                            selectedItems.append(tradeItem)
                            showQuantityPicker = false
                        } label: {
                            Text("添加到列表")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ApocalypseTheme.primary)
                                )
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("选择数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showQuantityPicker = false
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ItemPickerSheet(mode: .fromAllItems) { items in
        print("Selected: \(items)")
    }
}
