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

    private var period: String {
        isYearly ? "年" : "月"
    }

    private var autoRenewText: String {
        isYearly ? "每年自动续费" : "每月自动续费"
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

                        Text("确认订阅\(tier.displayName)?")
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

                            Text("/ \(period)")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        if isYearly,
                           let savingsPercent = SubscriptionProduct(rawValue: product.id)?.savingsPercent {
                            Text("比月卡节省 \(savingsPercent)%")
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
                        infoRow(icon: "checkmark.circle.fill", text: "订阅立即生效，权益即刻享受")
                        infoRow(icon: "arrow.clockwise.circle.fill", text: autoRenewText)
                        infoRow(icon: "xmark.circle.fill", text: "可随时取消，到期后自动停止")
                        infoRow(icon: "creditcard.circle.fill", text: "通过 Apple 账户安全支付")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.cardBackground)
                    )

                    // 权益预览
                    VStack(alignment: .leading, spacing: 8) {
                        Text("即将解锁")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            benefitBadge("背包容量 \(tier.backpackCapacity)")
                            benefitBadge("探索范围 \(String(format: "%.0f", tier.explorationRadius))km")
                            benefitBadge("建造速度 \(String(format: "%.0f", tier.buildSpeedMultiplier))倍")

                            if tier != .free {
                                benefitBadge("每日专属礼包")
                                benefitBadge("专属呼号前缀")
                            }

                            if tier == .lord {
                                benefitBadge("领主专属头衔")
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
                        Text("订阅即表示同意")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(spacing: 4) {
                            Button("《服务条款》") {
                                // TODO: 打开服务条款
                            }
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.primary)

                            Text("和")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Button("《隐私政策》") {
                                // TODO: 打开隐私政策
                            }
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
                        // 注意：成功后由父视图关闭sheet，这里不设置 isProcessing = false
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("处理中...")
                        } else {
                            Text("确认订阅")
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
                Button("取消") {
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
