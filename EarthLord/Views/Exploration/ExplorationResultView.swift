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

    /// 探索结果数据（可选，nil 表示失败）
    let result: ExplorationResult?

    /// 错误信息（可选）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 环境变量 - 关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent = false
    @State private var showItems = false

    /// 数字动画进度 (0-1)
    @State private var numberAnimationProgress: Double = 0

    /// 是否为错误状态
    private var isError: Bool {
        result == nil || errorMessage != nil
    }

    /// 动画显示的统计数值
    private var animatedDistanceCurrent: Double {
        (result?.distanceStats.current ?? 0) * numberAnimationProgress
    }
    private var animatedDistanceTotal: Double {
        (result?.distanceStats.total ?? 0) * numberAnimationProgress
    }
    private var animatedAreaCurrent: Double {
        (result?.areaStats.current ?? 0) * numberAnimationProgress
    }
    private var animatedAreaTotal: Double {
        (result?.areaStats.total ?? 0) * numberAnimationProgress
    }
    private var animatedDuration: TimeInterval {
        (result?.duration ?? 0) * numberAnimationProgress
    }
    private var animatedExperience: Int {
        Int(Double(result?.experienceGained ?? 0) * numberAnimationProgress)
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
        .onAppear {
            guard !isError else { return }
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
                Text("探索失败")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 错误信息
                Text(errorMessage ?? "探索过程中发生未知错误")
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
                                Text("重试")
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
                        Text("关闭")
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

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标 - 带光晕效果
            ZStack {
                // 光晕背景
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.4),
                                ApocalypseTheme.primary.opacity(0)
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
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 大标题
            Text("探索完成！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scaleEffect(showContent ? 1 : 0.8)
                .opacity(showContent ? 1 : 0)

            // 经验值
            if (result?.experienceGained ?? 0) > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)

                    Text("+\(animatedExperience) 经验值")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.yellow)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                )
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
            }
        }
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索数据")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 统计项
            VStack(spacing: 14) {
                // 行走距离
                StatRow(
                    icon: "figure.walk",
                    title: "行走距离",
                    current: formatDistance(animatedDistanceCurrent),
                    total: formatDistance(animatedDistanceTotal),
                    rank: result?.distanceStats.rank ?? 0
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索面积
                StatRow(
                    icon: "square.dashed",
                    title: "探索面积",
                    current: formatArea(animatedAreaCurrent),
                    total: formatArea(animatedAreaTotal),
                    rank: result?.areaStats.rank ?? 0
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索时长
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .frame(width: 20)

                        Text("探索时长")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    Text(formatDuration(animatedDuration))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        let obtainedItems = result?.obtainedItems ?? []

        return VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("获得物品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(obtainedItems.count)件")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 物品列表
            if obtainedItems.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("本次探索未获得物品")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(obtainedItems.enumerated()), id: \.element.itemId) { index, item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                            RewardItemRow(
                                name: definition.name,
                                quantity: item.quantity,
                                icon: definition.category.icon,
                                color: definition.category.color,
                                quality: item.quality,
                                showCheckmark: showItems,
                                animationDelay: Double(index) * 0.2
                            )
                            .opacity(showItems ? 1 : 0)
                            .offset(x: showItems ? 0 : -20)
                            .animation(
                                .easeOut(duration: 0.4).delay(Double(index) * 0.2),
                                value: showItems
                            )
                        }
                    }
                }

                // 底部提示
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
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

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))

                Text("确认收下")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
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

    /// 格式化面积
    private func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 10000 {
            return String(format: "%.1f万m²", squareMeters / 10000)
        } else {
            return "\(Int(squareMeters))m²"
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟"
        } else if minutes > 0 {
            return "\(minutes)分\(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }
}

// MARK: - 统计行组件

struct StatRow: View {
    let icon: String
    let title: String
    let current: String
    let total: String
    let rank: Int

    var body: some View {
        HStack(alignment: .top) {
            // 图标和标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 数据
            VStack(alignment: .trailing, spacing: 4) {
                // 本次
                HStack(spacing: 4) {
                    Text("本次")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(current)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 累计和排名
                HStack(spacing: 8) {
                    Text("累计 \(total)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 排名徽章
                    Text("#\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ApocalypseTheme.success.opacity(0.15))
                        )
                }
            }
        }
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

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.sampleExplorationResult)
}

#Preview("空物品") {
    let emptyResult = ExplorationResult(
        startTime: Date().addingTimeInterval(-600),
        endTime: Date(),
        distanceStats: DistanceStats(current: 800, total: 5000, rank: 156),
        areaStats: AreaStats(current: 15000, total: 80000, rank: 203),
        obtainedItems: [],
        experienceGained: 50
    )

    ExplorationResultView(result: emptyResult)
}

#Preview("Sheet 展示") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ExplorationResultView(result: MockExplorationData.sampleExplorationResult)
                .presentationDetents([.large])
        }
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
