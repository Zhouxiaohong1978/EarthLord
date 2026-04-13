//
//  PurchaseConfirmSheet.swift
//  EarthLord
//
//  购买确认弹窗
//

import SwiftUI
import StoreKit

struct PurchaseConfirmSheet: View {
    let product: Product
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    // 从产品ID获取配置信息
    private var packConfig: SupplyPackConfig? {
        guard let packProduct = SupplyPackProduct(rawValue: product.id) else {
            return nil
        }
        return SupplyPackConfig.all[packProduct]
    }

    // 礼包名本地化 key
    private var packNameKey: String {
        switch product.id {
        case "com.earthlord.survivor_pack":       return "pack.survivor.name"
        case "com.earthlord.constructor_pack":    return "pack.constructor.name"
        case "com.earthlord.engineer_pack":       return "pack.engineer.name"
        case "com.earthlord.rare_pack":           return "pack.rare.name"
        case "com.earthlord.comm_upgrade":        return "pack.comm_upgrade.name"
        case "com.earthlord.capacity_expansion":  return "pack.backpack_expand.name"
        default: return ""
        }
    }

    // 礼包描述本地化 key
    private var packDescKey: String {
        switch product.id {
        case "com.earthlord.survivor_pack":       return "pack.survivor.desc"
        case "com.earthlord.constructor_pack":    return "pack.constructor.desc"
        case "com.earthlord.engineer_pack":       return "pack.engineer.desc"
        case "com.earthlord.rare_pack":           return "pack.rare.desc"
        case "com.earthlord.comm_upgrade":        return "pack.comm_upgrade.tagline"
        case "com.earthlord.capacity_expansion":  return "pack.backpack_expand.tagline"
        default: return ""
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 产品图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "bag.fill")
                            .font(.system(size: 40))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .padding(.top, 20)

                    // 产品信息
                    VStack(spacing: 8) {
                        Group {
                            if packNameKey.isEmpty {
                                Text(product.displayName)
                            } else {
                                Text(LanguageManager.localizedStringSync(for: packNameKey))
                            }
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                        Group {
                            if packDescKey.isEmpty {
                                Text(product.description)
                            } else {
                                Text(LanguageManager.localizedStringSync(for: packDescKey))
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    }

                    // 价格
                    HStack(spacing: 4) {
                        Text(LanguageManager.localizedStringSync(for: "store.price.label"))
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(product.displayPrice)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    // 物品预览
                    if let config = packConfig {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LanguageManager.localizedStringSync(for: "store.contains"))
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(config.baseItems, id: \.itemId) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(LanguageManager.localizedStringSync(for: "item." + item.itemId))
                                                .font(.subheadline)
                                                .foregroundColor(ApocalypseTheme.textPrimary)
                                            + Text(" ×\(item.quantity)")
                                                .font(.subheadline)
                                                .foregroundColor(ApocalypseTheme.textPrimary)
                                        }
                                    }

                                    if !config.bonusItems.isEmpty {
                                        Divider()
                                            .background(ApocalypseTheme.textSecondary.opacity(0.2))

                                        ForEach(config.bonusItems, id: \.item.itemId) { bonus in
                                            HStack(spacing: 8) {
                                                Image(systemName: "star.circle.fill")
                                                    .foregroundColor(.orange)
                                                Text(LanguageManager.localizedStringSync(for: "item." + bonus.item.itemId))
                                                    .font(.subheadline)
                                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                                + Text(" ×\(bonus.item.quantity)")
                                                    .font(.subheadline)
                                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                                Spacer()
                                                Text("\(bonus.probability)%")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    // 提示信息
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(ApocalypseTheme.primary)
                        Text(LanguageManager.localizedStringSync(for: "store.info.desc"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    // 按钮组
                    VStack(spacing: 12) {
                        // 确认购买
                        Button(action: {
                            dismiss()
                            onConfirm()
                        }) {
                            Text(LanguageManager.localizedStringSync(for: "store.purchase.confirm"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(ApocalypseTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        // 取消
                        Button(action: {
                            dismiss()
                            onCancel()
                        }) {
                            Text(LanguageManager.localizedStringSync(for: "store.close"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(ApocalypseTheme.cardBackground)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    Text("购买确认弹窗预览")
}
