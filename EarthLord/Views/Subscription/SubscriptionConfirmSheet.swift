//
//  SubscriptionConfirmSheet.swift
//  EarthLord
//
//  订阅确认弹窗
//

import SwiftUI
import StoreKit

struct SubscriptionConfirmSheet: View {

    // MARK: - Properties

    let product: Product
    let tier: SubscriptionTier
    let onConfirm: () async -> Void
    let onCancel: () -> Void

    @State private var isProcessing = false

    // MARK: - Computed Properties

    private var isYearly: Bool {
        product.id.contains("yearly")
    }

    private var periodSuffix: String {
        isYearly ? String(localized: "period.yr.suffix") : String(localized: "period.mo.suffix")
    }

    private var autoRenewText: String {
        isYearly ? String(localized: "sub.confirm.autorenew.yearly") : String(localized: "sub.confirm.autorenew.monthly")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(ApocalypseTheme.primary)
                .frame(height: 4)

            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    VStack(spacing: 8) {
                        Text(tier.badgeIcon)
                            .font(.system(size: 48))

                        Text(String(format: String(localized: "sub.confirm.title"), tier.displayName))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(product.displayName)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 20)

                    // 价格卡片
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(product.displayPrice)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(ApocalypseTheme.primary)

                            Text(periodSuffix)
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        if isYearly,
                           let savingsPercent = SubscriptionProduct(rawValue: product.id)?.savingsPercent {
                            Text(String(format: String(localized: "sub.confirm.save"), savingsPercent))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.success)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(ApocalypseTheme.success.opacity(0.2))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                            )
                    )

                    // 订阅说明
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(icon: "checkmark.circle.fill", text: String(localized: "sub.confirm.active"))
                        infoRow(icon: "arrow.clockwise.circle.fill", text: autoRenewText)
                        infoRow(icon: "xmark.circle.fill", text: String(localized: "sub.confirm.cancel_policy"))
                        infoRow(icon: "creditcard.circle.fill", text: String(localized: "sub.confirm.payment"))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.cardBackground)
                    )

                    // 权益预览
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("sub.confirm.coming_soon"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            benefitBadge(String(format: String(localized: "sub.benefit.backpack"), tier.backpackCapacity))
                            benefitBadge(String(format: String(localized: "sub.benefit.range"), tier.explorationRadius))
                            benefitBadge(String(format: String(localized: "sub.benefit.build_speed"), tier.buildSpeedMultiplier))

                            if tier != .free {
                                benefitBadge(String(localized: "sub.benefit.daily_gift"))
                                benefitBadge(String(localized: "sub.benefit.callsign"))
                            }

                            if tier == .lord {
                                benefitBadge(String(localized: "sub.benefit.lord_title"))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.primary.opacity(0.1))
                    )

                    // 法律条款
                    VStack(spacing: 6) {
                        Text(LocalizedStringKey("sub.confirm.agree"))
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(spacing: 4) {
                            Link(String(localized: "sub.terms"), destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/terms.html")!)
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.primary)

                            Text(LocalizedStringKey("sub.confirm.and"))
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Link(String(localized: "sub.privacy_policy"), destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/privacy.html")!)
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
            }

            // 底部按钮
            VStack(spacing: 12) {
                // 确认订阅按钮
                Button(action: {
                    Task {
                        isProcessing = true
                        await onConfirm()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text(LocalizedStringKey("sub.confirm.processing"))
                        } else {
                            Text(LocalizedStringKey("sub.confirm.confirm"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isProcessing ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    )
                    .foregroundColor(.white)
                }
                .disabled(isProcessing)

                // 取消按钮
                Button(String(localized: "取消")) {
                    onCancel()
                }
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .disabled(isProcessing)
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
        }
        .background(ApocalypseTheme.background)
    }

    // MARK: - Helper Views

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    private func benefitBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("订阅确认弹窗预览")
            .font(.headline)
            .foregroundColor(ApocalypseTheme.textPrimary)

        Text("需要 StoreKit 配置文件才能预览")
            .font(.caption)
            .foregroundColor(ApocalypseTheme.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ApocalypseTheme.background)
}
