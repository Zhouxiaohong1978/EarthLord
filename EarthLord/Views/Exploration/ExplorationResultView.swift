//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果弹窗页面
//  显示探索完成后的统计数据和获得的物品奖励
//

import SwiftUI

// MARK: - 主视图

struct ExplorationResultView: View {
    // MARK: - 属性

    /// 探索会话结果（使用统一模型）
    let result: ExplorationSessionResult?

    /// 错误信息（可选）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 确认收取回调（传入勾选的物品 ID 集合）
    var onConfirm: ((Set<UUID>) -> Void)? = nil

    /// 环境变量 - 关闭页面
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 动画状态
    @State private var showContent = false
    @State private var showItems = false

    /// 数字动画进度 (0-1)
    @State private var numberAnimationProgress: Double = 0

    /// 累计距离和排名（异步加载）
    @State private var totalDistance: Double = 0
    @State private var rank: Int = 0

    /// 勾选的物品 ID
    @State private var selectedItemIds: Set<UUID> = []

    /// 是否显示订阅升级弹窗
    @State private var showSubscription = false

    private var obtainedItems: [ObtainedItem] { result?.obtainedItems ?? [] }

    private var remainingCapacity: Int { inventoryManager.remainingCapacity }

    private var selectedTotalQuantity: Int {
        obtainedItems
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.quantity }
    }

    private var isOverCapacity: Bool { selectedTotalQuantity > remainingCapacity }

    /// 是否为错误状态
    private var isError: Bool {
        result == nil || errorMessage != nil
    }

    /// 动画显示的距离
    private var animatedCurrentDistance: Double {
        (result?.distanceWalked ?? 0) * numberAnimationProgress
    }
    private var animatedTotalDistance: Double {
        totalDistance * numberAnimationProgress
    }
    private var animatedDuration: TimeInterval {
        Double(result?.durationSeconds ?? 0) * numberAnimationProgress
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if isError {
                // 错误状态
                errorStateView
            } else {
                // 成功状态
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部拖动指示器
                        dragIndicator

                        // 成就标题
                        achievementHeader
                            .padding(.top, 20)

                        // 统计数据卡片
                        statsCard
                            .padding(.horizontal, 20)
                            .padding(.top, 28)

                        // 奖励物品卡片
                        rewardsCard
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // 确认按钮
                        confirmButton
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .onAppear {
            guard !isError else { return }
            // 预选能装下的物品
            var usedCapacity = 0
            let capacity = inventoryManager.remainingCapacity
            for item in obtainedItems {
                if usedCapacity + item.quantity <= capacity {
                    selectedItemIds.insert(item.id)
                    usedCapacity += item.quantity
                }
            }
            // 延迟显示动画
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
            // 数字跳动动画
            withAnimation(.easeOut(duration: 1.2).delay(0.4)) {
                numberAnimationProgress = 1.0
            }
            // 物品列表动画
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showItems = true
            }
            // 异步加载累计统计
            Task {
                await loadStats()
            }
        }
    }

    /// 加载累计距离和排名
    private func loadStats() async {
        do {
            let stats = try await ExplorationStatsManager.shared.getStats()
            totalDistance = stats.totalDistance
            rank = stats.distanceRank
        } catch {
            // 加载失败时用本次距离作为fallback
            totalDistance = result?.distanceWalked ?? 0
            rank = 0
        }
    }

    // MARK: - 错误状态视图

    private var errorStateView: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示器
            dragIndicator

            Spacer()

            VStack(spacing: 20) {
                // 错误图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.danger.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(ApocalypseTheme.danger)
                }

                // 错误标题
                Text(LocalizedStringKey("探索失败"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 错误信息
                Text(errorMessage ?? String(localized: "探索过程中发生未知错误"))
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // 按钮区域
                VStack(spacing: 12) {
                    // 重试按钮
                    if let onRetry = onRetry {
                        Button {
                            onRetry()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizedStringKey("重试"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.primary)
                            )
                        }
                    }

                    // 关闭按钮
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("关闭"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Spacer()
        }
    }

    // MARK: - 拖动指示器

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(ApocalypseTheme.textMuted)
            .frame(width: 36, height: 5)
            .padding(.top, 12)
    }

    // MARK: - 成就标题

    /// 获取奖励等级
    private var rewardTier: RewardTier {
        result?.rewardTier ?? .none
    }

    /// 奖励等级颜色
    private var tierColor: Color {
        switch rewardTier {
        case .none:
            return .gray
        case .bronze:
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver:
            return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond:
            return Color(red: 0.0, green: 0.9, blue: 1.0)
        case .legendary:
            return Color(red: 0.7, green: 0.3, blue: 1.0)
        }
    }

    private var achievementHeader: some View {
        VStack(spacing: 12) {
            // 大图标 - 带光晕效果
            ZStack {
                // 光晕背景
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tierColor.opacity(0.4),
                                tierColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                // 图标背景圆
                Circle()
                    .fill(tierColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 等级图标
                Image(systemName: rewardTier.icon)
                    .font(.system(size: 44))
                    .foregroundColor(tierColor)
            }

            // 大标题
            Text(LocalizedStringKey("探索完成！"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scaleEffect(showContent ? 1 : 0.8)
                .opacity(showContent ? 1 : 0)

            // 奖励等级徽章
            if rewardTier != .none {
                rewardTierBadge
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
            }

            // 副标题
            Text(rewardTier == .none ? LocalizedStringKey("距离不足，未获得奖励") : LocalizedStringKey("你发现了新的区域和物资"))
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .opacity(showContent ? 1 : 0)
        }
    }

    // MARK: - 奖励等级徽章

    private var rewardTierBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: rewardTier.icon)
                .font(.system(size: 16, weight: .semibold))

            Text(rewardTier.displayName)
                .font(.system(size: 16, weight: .bold))

            Text(LocalizedStringKey("奖励"))
                .font(.system(size: 14, weight: .medium))
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tierColor, tierColor.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: tierColor.opacity(0.5), radius: 8, x: 0, y: 4)
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        VStack(spacing: 0) {
            // 行走距离
            StatRowNew(
                icon: "figure.walk",
                iconColor: .blue,
                title: String(localized: "行走距离"),
                currentValue: formatDistance(animatedCurrentDistance),
                totalValue: formatDistance(animatedTotalDistance),
                rank: rank
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                }

                // 标题
                Text(LocalizedStringKey("探索时长"))
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 时长值
                Text(formatDuration(animatedDuration))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(LocalizedStringKey("获得物品"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(obtainedItems.count)\(String(localized: "件"))")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 物品列表
            if obtainedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(LocalizedStringKey("本次探索未获得物品"))
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 背包容量提示
                capacityBanner

                VStack(spacing: 10) {
                    ForEach(Array(obtainedItems.enumerated()), id: \.element.id) { index, item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                            SelectableRewardItemRow(
                                item: item,
                                name: definition.name,
                                icon: definition.category.icon,
                                color: definition.category.color,
                                isSelected: selectedItemIds.contains(item.id)
                            ) {
                                if selectedItemIds.contains(item.id) {
                                    selectedItemIds.remove(item.id)
                                } else {
                                    selectedItemIds.insert(item.id)
                                }
                            }
                            .opacity(showItems ? 1 : 0)
                            .offset(x: showItems ? 0 : -20)
                            .animation(
                                .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                                value: showItems
                            )
                        }
                    }
                }

                // 超出容量警告
                if isOverCapacity {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.danger)
                        Text(LocalizedStringKey("已选物品超出剩余容量，请取消勾选部分物品"))
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                    .padding(.top, 4)
                }

                // 升级背包容量按钮
                Button {
                    showSubscription = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 13))
                        Text(LocalizedStringKey("升级背包容量"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .strokeBorder(ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(showItems ? 1 : 0)
        .offset(y: showItems ? 0 : 20)
    }

    private var capacityBanner: some View {
        VStack(spacing: 6) {
            HStack {
                Text(LocalizedStringKey("背包容量"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Spacer()
                Text("\(inventoryManager.totalItemCount + selectedTotalQuantity)/\(inventoryManager.backpackCapacity)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isOverCapacity ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOverCapacity ? ApocalypseTheme.danger : ApocalypseTheme.success)
                        .frame(width: geo.size.width * min(1, Double(inventoryManager.totalItemCount + selectedTotalQuantity) / Double(max(1, inventoryManager.backpackCapacity))))
                }
            }
            .frame(height: 6)
            Text(String(format: String(localized: "剩余 %lld 格，已选 %lld 格"), remainingCapacity, selectedTotalQuantity))
                .font(.system(size: 11))
                .foregroundColor(isOverCapacity ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        VStack(spacing: 12) {
            // 确认收取按钮
            if !obtainedItems.isEmpty {
                Button {
                    onConfirm?(selectedItemIds)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(selectedItemIds.isEmpty
                             ? LocalizedStringKey("放弃全部物品")
                             : LocalizedStringKey("确认收取"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Group {
                            if isOverCapacity {
                                ApocalypseTheme.textMuted
                            } else {
                                LinearGradient(
                                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .cornerRadius(14)
                }
                .disabled(isOverCapacity)
            }

            // 关闭/跳过按钮
            Button {
                dismiss()
            } label: {
                Text(obtainedItems.isEmpty ? LocalizedStringKey("关闭") : LocalizedStringKey("跳过，不收取物品"))
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .opacity(showItems ? 1 : 0)
    }

    // MARK: - 格式化方法

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return "\(Int(meters))m"
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)\(String(localized: "小时"))\(mins)\(String(localized: "分钟"))"
        } else if minutes > 0 {
            return "\(minutes)\(String(localized: "分"))\(secs)\(String(localized: "秒"))"
        } else {
            return "\(secs)\(String(localized: "秒"))"
        }
    }
}

// MARK: - 新版统计行组件

struct StatRowNew: View {
    let icon: String
    let iconColor: Color
    let title: String
    let currentValue: String
    let totalValue: String
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            // 标题和数值
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("本次"))
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(currentValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("累计"))
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(totalValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 排名
            if rank > 0 {
                VStack(spacing: 2) {
                    Text(LocalizedStringKey("排名"))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("#\(rank)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - 奖励物品行组件

struct RewardItemRow: View {
    let name: String
    let quantity: Int
    let icon: String
    let color: Color
    let quality: ItemQuality?
    var showCheckmark: Bool = true
    var animationDelay: Double = 0

    /// 对勾弹跳动画状态
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = quality {
                    Text(quality.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(quality.color)
                }
            }

            Spacer()

            // 数量
            Text("x\(quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾图标（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
                .onChange(of: showCheckmark) { newValue in
                    if newValue {
                        // 延迟后播放弹跳动画
                        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay + 0.3) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) {
                                checkmarkScale = 1.0
                            }
                        }
                    }
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }
}

// MARK: - 可勾选奖励物品行

struct SelectableRewardItemRow: View {
    let item: ObtainedItem
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 勾选框
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                // 物品图标
                ZStack {
                    Circle()
                        .fill(color.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? color : color.opacity(0.4))
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelected ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? quality.color : quality.color.opacity(0.4))
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? ApocalypseTheme.background
                          : ApocalypseTheme.background.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? ApocalypseTheme.success.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    let sampleResult = ExplorationSessionResult(
        id: UUID(),
        startTime: Date().addingTimeInterval(-1800),
        endTime: Date(),
        distanceWalked: 2500,
        durationSeconds: 1800,
        status: "completed",
        rewardTier: .gold,
        obtainedItems: [
            ObtainedItem(itemId: "wood", quantity: 5, quality: nil),
            ObtainedItem(itemId: "water_bottle", quantity: 3, quality: nil),
            ObtainedItem(itemId: "canned_food", quantity: 2, quality: .normal)
        ],
        path: [],
        maxSpeed: 5.2
    )
    ExplorationResultView(result: sampleResult)
}

#Preview("错误状态") {
    ExplorationResultView(
        result: nil,
        errorMessage: "网络连接超时，请检查网络后重试",
        onRetry: {
            print("重试探索")
        }
    )
}
