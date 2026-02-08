//
//  SubscriptionCard.swift
//  EarthLord
//
//  订阅档位卡片组件
//

import SwiftUI
import StoreKit

struct SubscriptionCard: View {

    // MARK: - Properties

    let product: Product
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    let isRecommended: Bool
    let onSubscribe: () async -> Void

    @State private var isSubscribing = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：徽章 + 推荐标签
            HStack {
                // 档位徽章和名称
                HStack(spacing: 8) {
                    Text(tier.badgeIcon)
                        .font(.system(size: 32))

                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 推荐标签
                if isRecommended {
                    Text("推荐")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary)
                        )
                }

                // 当前档位标签
                if isCurrentTier {
                    Text("当前档位")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                        )
                }
            }

            // 价格
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("/ \(product.id.contains("yearly") ? "年" : "月")")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 年卡优惠提示
                if product.id.contains("yearly"),
                   let savingsPercent = SubscriptionProduct(rawValue: product.id)?.savingsPercent {
                    Text("省\(savingsPercent)%")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.success.opacity(0.2))
                        )
                }
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 权益列表
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "backpack.fill", text: "背包容量 \(tier.backpackCapacity)")
                benefitRow(icon: "map.fill", text: "探索范围 \(String(format: "%.0f", tier.explorationRadius))km")
                benefitRow(icon: "building.2.fill", text: "建造速度 \(String(format: "%.0f", tier.buildSpeedMultiplier))倍")

                if let tradeLimit = tier.dailyTradeLimit {
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: "交易次数 \(tradeLimit)次/天")
                } else {
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: "交易次数 无限", highlight: true)
                }

                if let harvestLimit = tier.dailyHarvestLimit {
                    benefitRow(icon: "house.fill", text: "庇护所收益 \(harvestLimit)次/天")
                } else {
                    benefitRow(icon: "house.fill", text: "庇护所收益 无限", highlight: true)
                }

                // 订阅用户专属权益
                if tier != .free {
                    benefitRow(icon: "gift.fill", text: "每日专属礼包", highlight: true)
                    benefitRow(icon: "tag.fill", text: "专属呼号前缀", highlight: true)
                }

                // 领主专属权益
                if tier == .lord {
                    benefitRow(icon: "crown.fill", text: "领主专属头衔", highlight: true)
                    benefitRow(icon: "person.3.fill", text: "优先客服支持", highlight: true)
                }
            }

            // 订阅按钮
            if !isCurrentTier {
                Button(action: {
                    Task {
                        isSubscribing = true
                        await onSubscribe()
                        isSubscribing = false
                    }
                }) {
                    HStack {
                        if isSubscribing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("立即订阅")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSubscribing ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    )
                    .foregroundColor(.white)
                }
                .disabled(isSubscribing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isRecommended ? ApocalypseTheme.primary.opacity(0.5) :
                            ApocalypseTheme.textMuted.opacity(0.3),
                            lineWidth: isRecommended ? 2 : 1
                        )
                )
        )
    }

    // MARK: - Helper Views

    private func benefitRow(icon: String, text: String, highlight: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(highlight ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(highlight ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("订阅卡片预览")
            .font(.headline)
            .foregroundColor(ApocalypseTheme.textPrimary)

        Text("需要 StoreKit 配置文件才能预览")
            .font(.caption)
            .foregroundColor(ApocalypseTheme.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ApocalypseTheme.background)
}
