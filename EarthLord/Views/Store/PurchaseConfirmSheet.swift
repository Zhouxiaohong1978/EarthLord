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
                        Text(product.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(product.description)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // 价格
                    HStack(spacing: 4) {
                        Text("价格:")
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
                            Text("将获得以下物品")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(config.baseItems, id: \.itemId) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("\(item.itemId) ×\(item.quantity)")
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
                                                Text("\(bonus.item.itemId) ×\(bonus.item.quantity)")
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
                        Text("物品将发送到邮箱")
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
                            Text("确认购买")
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
                            Text("取消")
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
