//
//  SubscriptionResultView.swift
//  EarthLord
//
//  订阅结果页面（成功/失败）
//

import SwiftUI

struct SubscriptionResultView: View {

    // MARK: - Result Type

    enum ResultType {
        case success(tier: SubscriptionTier, expiresAt: Date)
        case failure(error: String)
        case cancelled
    }

    // MARK: - Properties

    let result: ResultType
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(statusColor)
                .frame(height: 4)

            ScrollView {
                VStack(spacing: 24) {
                    // 顶部间距
                    Spacer()
                        .frame(height: 20)

                    // 状态图标
                    Image(systemName: statusIcon)
                        .font(.system(size: 64))
                        .foregroundColor(statusColor)
                        .padding(.bottom, 8)

                    // 根据结果类型显示内容
                    switch result {
                    case .success(let tier, let expiresAt):
                        successContent(tier: tier, expiresAt: expiresAt)

                    case .failure(let error):
                        failureContent(error: error)

                    case .cancelled:
                        cancelledContent()
                    }

                    // 底部间距
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 16)
            }

            // 底部按钮
            Button(action: onDismiss) {
                Text(result.isSuccess ? "开始探索" : "知道了")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(statusColor)
                    )
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
        }
        .background(ApocalypseTheme.background)
    }

    // MARK: - Success Content

    @ViewBuilder
    private func successContent(tier: SubscriptionTier, expiresAt: Date) -> some View {
        VStack(spacing: 16) {
            // 标题
            Text("订阅成功！")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 档位徽章
            HStack(spacing: 8) {
                Text(tier.badgeIcon)
                    .font(.system(size: 40))

                Text("欢迎成为\(tier.displayName)")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                    )
            )

            // 到期时间
            VStack(spacing: 4) {
                Text("订阅有效期至")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(formatDate(expiresAt))
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.top, 8)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.vertical, 8)

            // 已解锁权益
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("已解锁权益")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    benefitRow(icon: "backpack.fill", text: "背包容量提升至 \(tier.backpackCapacity)")
                    benefitRow(icon: "map.fill", text: "探索范围扩大至 \(String(format: "%.0f", tier.explorationRadius))km")
                    benefitRow(icon: "building.2.fill", text: "建造速度 \(String(format: "%.0f", tier.buildSpeedMultiplier))倍加速")
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: tier.dailyTradeLimit == nil ? "无限次交易" : "每日交易 \(tier.dailyTradeLimit!)次")
                    benefitRow(icon: "house.fill", text: tier.dailyHarvestLimit == nil ? "无限次庇护所收益" : "每日庇护所收益 \(tier.dailyHarvestLimit!)次")
                    benefitRow(icon: "gift.fill", text: "每日专属礼包")
                    benefitRow(icon: "tag.fill", text: "专属呼号前缀")

                    if tier == .lord {
                        benefitRow(icon: "crown.fill", text: "领主专属头衔")
                        benefitRow(icon: "person.3.fill", text: "优先客服支持")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )

            // 温馨提示
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(ApocalypseTheme.info)
                    Text("温馨提示")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("• 所有权益已立即生效")
                    Text("• 订阅将自动续费，可随时在设置中取消")
                    Text("• 如有问题，请联系客服")
                }
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.info.opacity(0.1))
            )
        }
    }

    // MARK: - Failure Content

    @ViewBuilder
    private func failureContent(error: String) -> some View {
        VStack(spacing: 16) {
            Text("订阅失败")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(error)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("可能的原因")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("• 网络连接不稳定")
                    Text("• Apple ID 账户问题")
                    Text("• 支付方式无法使用")
                    Text("• 服务器暂时繁忙")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )

            Text("请稍后重试，或联系客服获取帮助")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Cancelled Content

    @ViewBuilder
    private func cancelledContent() -> some View {
        VStack(spacing: 16) {
            Text("已取消订阅")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("您可以随时回来订阅，解锁更多专属权益")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Helper Views

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch result {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        case .cancelled:
            return "hand.raised.fill"
        }
    }

    private var statusColor: Color {
        switch result {
        case .success:
            return ApocalypseTheme.success
        case .failure:
            return ApocalypseTheme.danger
        case .cancelled:
            return ApocalypseTheme.warning
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - ResultType Extension

extension SubscriptionResultView.ResultType {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

// MARK: - Preview

#Preview("成功") {
    SubscriptionResultView(
        result: .success(
            tier: .lord,
            expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        ),
        onDismiss: {
            print("关闭")
        }
    )
}

#Preview("失败") {
    SubscriptionResultView(
        result: .failure(error: "支付被取消或网络连接失败"),
        onDismiss: {
            print("关闭")
        }
    )
}

#Preview("取消") {
    SubscriptionResultView(
        result: .cancelled,
        onDismiss: {
            print("关闭")
        }
    )
}
