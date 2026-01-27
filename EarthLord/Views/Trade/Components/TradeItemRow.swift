//
//  TradeItemRow.swift
//  EarthLord
//
//  交易物品行组件
//  显示物品图标、名称、品质、数量
//

import SwiftUI

struct TradeItemRow: View {
    let item: TradeItem
    var showDeleteButton: Bool = false
    var showQuantityStepper: Bool = false
    var onDelete: (() -> Void)?
    var onQuantityChange: ((Int) -> Void)?

    @State private var quantity: Int

    init(
        item: TradeItem,
        showDeleteButton: Bool = false,
        showQuantityStepper: Bool = false,
        onDelete: (() -> Void)? = nil,
        onQuantityChange: ((Int) -> Void)? = nil
    ) {
        self.item = item
        self.showDeleteButton = showDeleteButton
        self.showQuantityStepper = showQuantityStepper
        self.onDelete = onDelete
        self.onQuantityChange = onQuantityChange
        self._quantity = State(initialValue: item.quantity)
    }

    /// 获取物品定义
    private var itemDefinition: ItemDefinition? {
        MockExplorationData.getItemDefinition(by: item.itemId)
    }

    /// 物品分类
    private var category: ItemCategory {
        itemDefinition?.category ?? .misc
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            itemIcon

            // 物品信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // 数量
                    if !showQuantityStepper {
                        Text("x\(item.quantity)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    // 品质
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(quality.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(quality.color.opacity(0.15))
                            )
                    }
                }
            }

            Spacer()

            // 数量调节器
            if showQuantityStepper {
                QuantityStepperView(value: $quantity, min: 1, max: 99)
                    .onChange(of: quantity) { newValue in
                        onQuantityChange?(newValue)
                    }
            }

            // 删除按钮
            if showDeleteButton {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 物品图标

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.2))
                .frame(width: 36, height: 36)

            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(category.color)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TradeItemRow(
            item: TradeItem(itemId: "wood", quantity: 10, quality: nil)
        )

        TradeItemRow(
            item: TradeItem(itemId: "bandage", quantity: 5, quality: .normal),
            showDeleteButton: true
        )

        TradeItemRow(
            item: TradeItem(itemId: "medicine", quantity: 3, quality: .excellent),
            showQuantityStepper: true
        )
    }
    .padding()
    .background(ApocalypseTheme.cardBackground)
}
