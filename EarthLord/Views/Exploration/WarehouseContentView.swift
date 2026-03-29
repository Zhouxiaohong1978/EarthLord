//
//  WarehouseContentView.swift
//  EarthLord
//
//  领地仓库视图 - 存取物品
//

import SwiftUI

struct WarehouseContentView: View {

    @ObservedObject private var warehouseManager = WarehouseManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @State private var showDepositSheet = false
    @State private var selectedItem: WarehouseItem?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        Group {
            if warehouseManager.isLoading && warehouseManager.totalCapacity == 0 {
                // 首次加载中，避免误显示"暂无仓库"
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !warehouseManager.hasWarehouse {
                noWarehouseView
            } else {
                warehouseView
            }
        }
        .task { await warehouseManager.refreshItems() }
        .sheet(isPresented: $showDepositSheet) {
            DepositSheet()
        }
        .sheet(item: $selectedItem) { item in
            WithdrawSheet(item: item)
        }
        .alert("操作失败", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 无仓库状态

    private var noWarehouseView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("尚未建造仓库")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("在领地中建造小仓库，\n即可存放背包装不下的物资")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - 仓库主视图

    private var warehouseView: some View {
        VStack(spacing: 0) {
            capacityBar
            if warehouseManager.remainingCapacity == 0 {
                fullWarningBanner
            }
            if warehouseManager.items.isEmpty {
                emptyWarehouseView
            } else {
                itemList
            }
        }
    }

    // MARK: - 满仓提示

    private var upgradeHint: (message: String, action: String, canNavigate: Bool) {
        let buildings = BuildingManager.shared.playerBuildings.filter { $0.status == .active }
        let smallWarehouses = buildings.filter { $0.templateId == "storage_small" }
        let mediumWarehouses = buildings.filter { $0.templateId == "storage_medium" }

        let smallMaxed = !smallWarehouses.isEmpty && smallWarehouses.allSatisfy { $0.level >= 3 }
        let mediumMaxed = !mediumWarehouses.isEmpty && mediumWarehouses.allSatisfy { $0.level >= 3 }
        let hasMedium = !mediumWarehouses.isEmpty

        if !smallMaxed {
            return ("小仓库尚未升至最高等级", "升级仓库", true)
        } else if !hasMedium {
            return ("小仓库已达最高等级，建造中仓库可大幅扩容", "建造中仓库", true)
        } else if !mediumMaxed {
            return ("中仓库尚未升至最高等级", "升级仓库", true)
        } else {
            return ("所有仓库已达最大容量，请取出物资腾出空间", "", false)
        }
    }

    private var fullWarningBanner: some View {
        let hint = upgradeHint
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.danger)

            VStack(alignment: .leading, spacing: 2) {
                Text("仓库已满")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.danger)
                Text(hint.message)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            if hint.canNavigate {
                Button {
                    NotificationCenter.default.post(name: .navigateToTerritoryTab, object: nil)
                } label: {
                    Text(hint.action)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.danger)
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .overlay(Rectangle().fill(ApocalypseTheme.danger.opacity(0.3)).frame(height: 1), alignment: .bottom)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - 容量进度条

    private var capacityBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("领地仓库")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        Text("\(warehouseManager.usedCapacity)/\(warehouseManager.totalCapacity) 格")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(capacityColor)
                    }

                    GeometryReader { geo in
                        let pct = warehouseManager.totalCapacity > 0
                            ? min(Double(warehouseManager.usedCapacity) / Double(warehouseManager.totalCapacity), 1.0)
                            : 0.0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(capacityColor)
                                .frame(width: geo.size.width * pct, height: 5)
                        }
                    }
                    .frame(height: 5)
                }

                Button {
                    showDepositSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 12))
                        Text("存入")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
                .disabled(warehouseManager.remainingCapacity == 0)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var capacityColor: Color {
        let pct = warehouseManager.totalCapacity > 0
            ? Double(warehouseManager.usedCapacity) / Double(warehouseManager.totalCapacity)
            : 0.0
        return pct > 0.9 ? ApocalypseTheme.danger : (pct > 0.7 ? ApocalypseTheme.warning : ApocalypseTheme.success)
    }

    // MARK: - 空仓库

    private var emptyWarehouseView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("仓库空空如也")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("背包满了？点击「存入」把物资转移到仓库")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(warehouseManager.groupedItems) { item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                        WarehouseItemCard(item: item, definition: definition) {
                            selectedItem = item
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 仓库物品卡片

struct WarehouseItemCard: View {
    let item: WarehouseItem
    let definition: ItemDefinition
    let onWithdraw: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(definition.category.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: definition.category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(definition.category.color)
            }

            // 名称 + 稀有度
            VStack(alignment: .leading, spacing: 4) {
                Text(item.customName ?? LanguageManager.shared.localizedString(for: definition.name))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                if item.customName != nil {
                    Text(LanguageManager.shared.localizedString(for: definition.name))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                Text(LanguageManager.shared.localizedString(for: definition.rarity.rawValue))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(definition.rarity.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(definition.rarity.color.opacity(0.15)))
            }

            Spacer()

            // 数量 + 取出按钮
            VStack(alignment: .trailing, spacing: 6) {
                Text("x\(item.quantity)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Button(action: onWithdraw) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.from.line")
                            .font(.system(size: 11))
                        Text("取出")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ApocalypseTheme.primary, lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }
}

// MARK: - 存入 Sheet

struct DepositSheet: View {
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var warehouseManager = WarehouseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: BackpackItem?
    @State private var quantity: Int = 1
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var depositableItems: [(itemId: String, quantity: Int, item: BackpackItem)] {
        var seen = Set<String>()
        return inventoryManager.items.compactMap { item in
            guard !seen.contains(item.itemId) else { return nil }
            seen.insert(item.itemId)
            let total = inventoryManager.items
                .filter { $0.itemId == item.itemId }
                .reduce(0) { $0 + $1.quantity }
            return (itemId: item.itemId, quantity: total, item: item)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()
                if depositableItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bag")
                            .font(.system(size: 44))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text("背包没有可存入的物品")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            Text("剩余仓库容量：\(warehouseManager.remainingCapacity) 格")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(depositableItems, id: \.itemId) { group in
                                if let definition = MockExplorationData.getItemDefinition(by: group.itemId) {
                                    DepositItemRow(
                                        item: group.item,
                                        definition: definition,
                                        totalQuantity: group.quantity,
                                        maxDeposit: min(group.quantity, warehouseManager.remainingCapacity),
                                        isProcessing: isProcessing
                                    ) { qty in
                                        await deposit(item: group.item, quantity: qty)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("存入仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("存入失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func deposit(item: BackpackItem, quantity: Int) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            // quality 传 nil：同种物品不区分品质合并存入
            try await warehouseManager.deposit(
                itemId: item.itemId,
                quantity: quantity,
                quality: nil,
                customName: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 存入物品行

struct DepositItemRow: View {
    let item: BackpackItem
    let definition: ItemDefinition
    let totalQuantity: Int
    let maxDeposit: Int
    let isProcessing: Bool
    let onDeposit: (Int) async -> Void

    @State private var qty: Int = 1
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(definition.category.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: definition.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(definition.category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.customName ?? LanguageManager.shared.localizedString(for: definition.name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("背包 x\(totalQuantity)")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 数量选择器
            HStack(spacing: 8) {
                Button { if qty > 1 { qty -= 1 } } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(qty > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                Text("\(qty)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 28)
                Button { if qty < maxDeposit { qty += 1 } } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(qty < maxDeposit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
            }

            Button {
                Task {
                    isLoading = true
                    await onDeposit(qty)
                    qty = 1
                    isLoading = false
                }
            } label: {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Text("存入")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 48, height: 30)
            .background(maxDeposit > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.4))
            .cornerRadius(8)
            .disabled(maxDeposit <= 0 || isLoading || isProcessing)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
        .onAppear { qty = min(1, maxDeposit) }
    }
}

// MARK: - 取出 Sheet

struct WithdrawSheet: View {
    let item: WarehouseItem
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var qty: Int = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var definition: ItemDefinition? { MockExplorationData.getItemDefinition(by: item.itemId) }
    private var maxWithdraw: Int { min(item.quantity, inventoryManager.remainingCapacity) }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    // 物品信息
                    if let def = definition {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle().fill(def.category.color.opacity(0.15)).frame(width: 80, height: 80)
                                Image(systemName: def.category.icon).font(.system(size: 32)).foregroundColor(def.category.color)
                            }
                            Text(item.customName ?? LanguageManager.shared.localizedString(for: def.name))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Text("仓库库存：x\(item.quantity)")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text("背包可用容量：\(inventoryManager.remainingCapacity) 格")
                                .font(.system(size: 14))
                                .foregroundColor(maxWithdraw > 0 ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
                        }
                    }

                    // 数量选择
                    HStack(spacing: 20) {
                        Button { if qty > 1 { qty -= 1 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(qty > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                        Text("\(qty)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(minWidth: 60)
                        Button { if qty < maxWithdraw { qty += 1 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(qty < maxWithdraw ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                    }

                    // 取出按钮
                    Button {
                        Task {
                            isLoading = true
                            do {
                                try await WarehouseManager.shared.withdraw(item: item, quantity: qty)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up.from.line")
                                Text("取出 \(qty) 件到背包")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(maxWithdraw > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.4))
                        .cornerRadius(14)
                    }
                    .disabled(maxWithdraw <= 0 || isLoading)
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationTitle("从仓库取出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("取出失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .onAppear { qty = min(1, maxWithdraw) }
    }
}

#Preview {
    WarehouseContentView()
}
