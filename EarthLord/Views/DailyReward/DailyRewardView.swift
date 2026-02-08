//
//  DailyRewardView.swift
//  EarthLord
//
//  每日礼包页面
//

import SwiftUI

struct DailyRewardView: View {

    // MARK: - State

    @ObservedObject private var rewardManager = DailyRewardManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showClaimSuccess = false
    @State private var showError = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if subscriptionManager.currentTier == .free {
                // 未订阅提示
                notSubscribedView
            } else {
                // 订阅用户的礼包界面
                subscribedView
            }
        }
        .navigationTitle("每日礼包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .onAppear {
            // 如果已有礼包数据，跳过网络请求
            if rewardManager.todayReward != nil {
                return
            }
            // 先同步更新礼包配置（不需要网络）
            rewardManager.updateTodayRewardPublic()
            // 延迟1秒再检查领取状态，避免NavigationLink转场期间的GCD并发崩溃
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task {
                    await rewardManager.checkTodayStatus()
                }
            }
        }
        .alert("领取成功", isPresented: $showClaimSuccess) {
            Button("好的", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("礼包已放入背包")
        }
        .alert("领取失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(rewardManager.errorMessage ?? "未知错误")
        }
    }

    // MARK: - 未订阅视图

    private var notSubscribedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gift.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("每日礼包")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("订阅探索者或领主，每日领取专属礼包")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal, 40)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("每日自动刷新")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("珍稀物资奖励")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("领主礼包更丰厚")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            Spacer()

            NavigationLink {
                SubscriptionView()
            } label: {
                Text("立即订阅")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.primary)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    // MARK: - 订阅用户视图

    private var subscribedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部状态
                statusSection

                // 礼包内容
                if let reward = rewardManager.todayReward {
                    rewardContentSection(reward: reward)
                }

                // 领取按钮
                claimButton

                // 温馨提示
                tipsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 状态部分

    private var statusSection: some View {
        VStack(spacing: 16) {
            // 图标和标题
            HStack(spacing: 12) {
                Text(subscriptionManager.currentTier.badgeIcon)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(subscriptionManager.currentTier.displayName)专属礼包")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if rewardManager.hasClaimedToday {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.success)

                            Text("今日已领取")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.success)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.primary)

                            Text("今日可领取")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                rewardManager.hasClaimedToday ?
                                    ApocalypseTheme.success.opacity(0.3) :
                                    ApocalypseTheme.primary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    // MARK: - 礼包内容部分

    private func rewardContentSection(reward: DailyRewardConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("礼包内容")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(spacing: 8) {
                ForEach(reward.items, id: \.itemId) { item in
                    rewardItemRow(item: item)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 礼包物品行

    private func rewardItemRow(item: DailyRewardConfig.RewardItem) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            Image(systemName: getItemIcon(itemId: item.itemId))
                .font(.title3)
                .foregroundColor(getItemColor(itemId: item.itemId))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(getItemColor(itemId: item.itemId).opacity(0.15))
                )

            // 物品名称
            VStack(alignment: .leading, spacing: 2) {
                Text(getItemName(itemId: item.itemId))
                    .font(.callout)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = item.quality {
                    Text(quality.rawValue)
                        .font(.caption2)
                        .foregroundColor(getQualityColor(quality: quality))
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 领取按钮

    private var claimButton: some View {
        Button(action: {
            Task {
                do {
                    try await rewardManager.claimTodayReward()
                    showClaimSuccess = true
                } catch {
                    rewardManager.errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }) {
            HStack {
                if rewardManager.isClaiming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("领取中...")
                } else if rewardManager.hasClaimedToday {
                    Image(systemName: "checkmark.circle.fill")
                    Text("今日已领取")
                } else {
                    Image(systemName: "gift.fill")
                    Text("领取礼包")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        rewardManager.hasClaimedToday || rewardManager.isClaiming ?
                            ApocalypseTheme.textMuted :
                            ApocalypseTheme.primary
                    )
            )
        }
        .disabled(rewardManager.hasClaimedToday || rewardManager.isClaiming)
    }

    // MARK: - 提示部分

    private var tipsSection: some View {
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
                Text("• 每日0点刷新，请及时领取")
                Text("• 领取后物品将直接放入背包")
                Text("• 礼包内容根据订阅档位变化")
                Text("• 订阅期间每天都可领取")
            }
            .font(.caption2)
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.info.opacity(0.1))
        )
    }

    // MARK: - Helper Methods

    private func getItemName(itemId: String) -> String {
        MockExplorationData.getItemDefinition(by: itemId)?.name ?? itemId
    }

    private func getItemIcon(itemId: String) -> String {
        if let definition = MockExplorationData.getItemDefinition(by: itemId) {
            switch definition.category {
            case .water: return "drop.fill"
            case .food: return "fork.knife"
            case .medical: return "cross.case.fill"
            case .material:
                if itemId.contains("wood") { return "tree.fill" }
                if itemId.contains("metal") { return "hammer.fill" }
                if itemId.contains("glass") { return "sparkles" }
                return "cube.fill"
            case .tool:
                if itemId.contains("flashlight") { return "flashlight.on.fill" }
                if itemId.contains("rope") { return "lasso" }
                return "wrench.fill"
            default: return "cube.box.fill"
            }
        }
        return "cube.box.fill"
    }

    private func getItemColor(itemId: String) -> Color {
        if let definition = MockExplorationData.getItemDefinition(by: itemId) {
            switch definition.category {
            case .water: return .blue
            case .food: return .orange
            case .medical: return .red
            case .material:
                if itemId.contains("wood") { return .brown }
                if itemId.contains("glass") { return .cyan }
                return .gray
            case .tool:
                if itemId.contains("flashlight") { return .yellow }
                return .gray
            default: return ApocalypseTheme.primary
            }
        }
        return ApocalypseTheme.primary
    }

    private func getQualityColor(quality: ItemQuality) -> Color {
        switch quality {
        case .broken:
            return ApocalypseTheme.danger
        case .worn:
            return ApocalypseTheme.warning
        case .normal:
            return ApocalypseTheme.textSecondary
        case .good:
            return ApocalypseTheme.success
        case .excellent:
            return ApocalypseTheme.primary
        }
    }
}

// MARK: - Preview

#Preview("已订阅 - 未领取") {
    NavigationStack {
        DailyRewardView()
    }
}

#Preview("未订阅") {
    NavigationStack {
        DailyRewardView()
    }
}
