//
//  SupplyPackCard.swift
//  EarthLord
//
//  物资包卡片组件
//

import SwiftUI
import StoreKit

struct SupplyPackCard: View {
    let product: Product
    let onPurchase: () -> Void

    // 从产品ID获取配置信息
    private var packConfig: SupplyPackConfig? {
        guard let packProduct = SupplyPackProduct(rawValue: product.id) else {
            return nil
        }
        return SupplyPackConfig.all[packProduct]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：产品名称和价格
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // 价格标签
                VStack(spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 物品列表
            if let config = packConfig {
                VStack(alignment: .leading, spacing: 8) {
                    Text("包含物品")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 基础物品
                    ForEach(config.baseItems, id: \.itemId) { item in
                        PackItemRow(
                            itemId: item.itemId,
                            quantity: item.quantity,
                            quality: item.quality
                        )
                    }

                    // 额外奖励
                    if !config.bonusItems.isEmpty {
                        Divider()
                            .background(ApocalypseTheme.textSecondary.opacity(0.1))

                        Text("额外奖励（概率获得）")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.primary)

                        ForEach(config.bonusItems, id: \.item.itemId) { bonus in
                            HStack(spacing: 4) {
                                PackItemRow(
                                    itemId: bonus.item.itemId,
                                    quantity: bonus.item.quantity,
                                    quality: bonus.item.quality
                                )

                                Spacer()

                                Text("\(bonus.probability)%")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            // 购买按钮
            Button(action: onPurchase) {
                HStack {
                    Image(systemName: "bag.fill")
                    Text("购买")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 物品行组件

struct PackItemRow: View {
    let itemId: String
    let quantity: Int
    let quality: String?

    var body: some View {
        HStack(spacing: 8) {
            // 物品图标
            Image(systemName: "cube.box.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)

            // 物品名称
            Text(itemId)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 数量
            Text("×\(quantity)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.primary)

            // 品质标签
            if let quality = quality {
                Text(quality)
                    .font(.caption2)
                    .foregroundColor(qualityColor(quality))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(qualityColor(quality).opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality.lowercased() {
        case "legendary": return .purple
        case "epic": return .orange
        case "rare": return .blue
        case "good": return .green
        default: return ApocalypseTheme.textSecondary
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // 预览需要模拟 Product，这里仅作示例
            Text("物资包卡片预览")
                .foregroundColor(.white)
        }
        .padding()
        .background(ApocalypseTheme.background)
    }
}
