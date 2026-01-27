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
}

struct ItemPickerSheet: View {
    let mode: ItemPickerMode
    let onSelect: ([TradeItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory?
    @State private var selectedItems: [TradeItem] = []
    @State private var showQuantityPicker = false
    @State private var pendingItem: SelectableItem?
    @State private var pendingQuantity = 1

    /// 可选物品列表
    private var selectableItems: [SelectableItem] {
        switch mode {
        case .fromInventory:
            return inventoryManager.items.compactMap { backpackItem in
                guard let definition = MockExplorationData.getItemDefinition(by: backpackItem.itemId) else {
                    return nil
                }
                return SelectableItem(
                    id: backpackItem.id.uuidString,
                    definition: definition,
                    availableQuantity: backpackItem.quantity,
                    quality: backpackItem.quality
                )
            }
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

        // 分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.definition.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter {
                $0.definition.name.localizedCaseInsensitiveContains(searchText)
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
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
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
        let isSelected = selectedItems.contains { $0.itemId == item.definition.id }

        return Button {
            if isSelected {
                // 取消选择
                selectedItems.removeAll { $0.itemId == item.definition.id }
            } else {
                // 选择物品，弹出数量选择
                pendingItem = item
                pendingQuantity = 1
                showQuantityPicker = true
            }
        } label: {
            HStack(spacing: 12) {
                // 物品图标
                ZStack {
                    Circle()
                        .fill(item.definition.category.color.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: item.definition.category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(item.definition.category.color)
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.definition.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 6) {
                        // 稀有度
                        Text(item.definition.rarity.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(item.definition.rarity.color)

                        // 库存数量
                        if let quantity = item.availableQuantity {
                            Text("库存: \(quantity)")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        // 品质
                        if let quality = item.quality {
                            Text(quality.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(quality.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(quality.color.opacity(0.15))
                                )
                        }
                    }
                }

                Spacer()

                // 选中状态
                if isSelected {
                    if let selected = selectedItems.first(where: { $0.itemId == item.definition.id }) {
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

                            Text(item.definition.name)
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
                                itemId: item.definition.id,
                                quantity: pendingQuantity,
                                quality: item.quality
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
