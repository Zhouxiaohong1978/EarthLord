//
//  TradeHubView.swift
//  EarthLord
//
//  交易中心入口
//  三入口卡片布局（交易市场/我的挂单/交易历史）
//

import SwiftUI

struct TradeHubView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 头部统计
                    headerStats

                    // 三入口卡片
                    VStack(spacing: 12) {
                        // 交易市场
                        NavigationLink {
                            TradeMarketView()
                        } label: {
                            entryCard(
                                title: LocalizedStringKey("交易市场"),
                                subtitle: LocalizedStringKey("浏览其他玩家的挂单"),
                                icon: "storefront.fill",
                                iconColor: ApocalypseTheme.primary,
                                count: tradeManager.availableOffers.count,
                                countLabel: LocalizedStringKey("可用挂单")
                            )
                        }

                        // 我的挂单
                        NavigationLink {
                            MyTradeOffersView()
                        } label: {
                            entryCard(
                                title: LocalizedStringKey("我的挂单"),
                                subtitle: LocalizedStringKey("管理您发布的挂单"),
                                icon: "list.bullet.rectangle.fill",
                                iconColor: ApocalypseTheme.info,
                                count: activeOffersCount,
                                countLabel: LocalizedStringKey("进行中")
                            )
                        }

                        // 交易历史
                        NavigationLink {
                            TradeHistoryView()
                        } label: {
                            entryCard(
                                title: LocalizedStringKey("交易历史"),
                                subtitle: LocalizedStringKey("查看已完成的交易"),
                                icon: "clock.arrow.circlepath",
                                iconColor: ApocalypseTheme.success,
                                count: tradeManager.tradeHistory.count,
                                countLabel: LocalizedStringKey("笔交易")
                            )
                        }
                    }

                    // 快捷发布按钮
                    quickPublishButton
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .navigationTitle(LocalizedStringKey("交易中心"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await tradeManager.refreshAll()
        }
    }

    // MARK: - 进行中的挂单数

    private var activeOffersCount: Int {
        tradeManager.myOffers.filter { $0.status == .active }.count
    }

    // MARK: - 头部统计

    private var dailyLimit: Int? {
        SubscriptionManager.shared.dailyTradeLimit
    }

    private var todayTradeLabel: String {
        if let limit = dailyLimit {
            return "\(tradeManager.todayTradeCount)/\(limit)"
        }
        return "\(tradeManager.todayTradeCount)"
    }

    private var todayTradeColor: Color {
        guard let limit = dailyLimit else { return ApocalypseTheme.success }
        let ratio = Double(tradeManager.todayTradeCount) / Double(limit)
        if ratio >= 1.0 { return ApocalypseTheme.danger }
        if ratio >= 0.8 { return ApocalypseTheme.warning }
        return ApocalypseTheme.success
    }

    private var headerStats: some View {
        VStack(spacing: 12) {
            // 上行：市场挂单 + 我的挂单
            HStack(spacing: 0) {
                statItem(
                    value: "\(tradeManager.availableOffers.count)",
                    label: "市场挂单",
                    icon: "cart.fill",
                    color: ApocalypseTheme.primary
                )
                Divider().frame(height: 40).background(ApocalypseTheme.textMuted.opacity(0.3))
                statItem(
                    value: "\(activeOffersCount)",
                    label: "我的挂单",
                    icon: "tag.fill",
                    color: ApocalypseTheme.info
                )
            }

            // 下行：今日交易次数（有限制时显示进度条）
            if let limit = dailyLimit {
                tradeLimitBar(used: tradeManager.todayTradeCount, limit: limit)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "infinity")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.success)
                    Text(String(localized: "今日交易次数不限"))
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }

    /// 今日交易次数进度条
    private func tradeLimitBar(used: Int, limit: Int) -> some View {
        let ratio = min(Double(used) / Double(limit), 1.0)
        let remaining = max(0, limit - used)
        let barColor: Color = ratio >= 1.0 ? ApocalypseTheme.danger
                            : ratio >= 0.7 ? ApocalypseTheme.warning
                            : ApocalypseTheme.success

        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11))
                        .foregroundColor(barColor)
                    Text(String(localized: "今日交易次数"))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                Spacer()
                if remaining > 0 {
                    Text(String(format: String(localized: "还剩 %d 次"), remaining))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(barColor)
                } else {
                    Text(String(localized: "今日已用完"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.danger)
                }
                Text("(\(used)/\(limit))")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * ratio, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: ratio)
                }
            }
            .frame(height: 6)

            // 快用完时的提示
            if ratio >= 0.7 && ratio < 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(String(format: String(localized: "订阅探索者或领主可解锁无限次交易"), remaining))
                        .font(.system(size: 10))
                }
                .foregroundColor(ApocalypseTheme.warning.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
    }

    private func statItem(value: String, label: String, icon: String, color: Color, subtitle: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(verbatim: value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(LocalizedStringKey(label))
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textMuted.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 入口卡片

    private func entryCard(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        iconColor: Color,
        count: Int,
        countLabel: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }

            // 标题和副标题
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 计数和箭头
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)

                Text(countLabel)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 快捷发布按钮

    @State private var showCreateSheet = false

    private var isTradeBlocked: Bool {
        guard let limit = dailyLimit else { return false }
        return tradeManager.todayTradeCount >= limit
    }

    private var quickPublishButton: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isTradeBlocked ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18))

                Text(isTradeBlocked ? LocalizedStringKey("今日次数已用完") : LocalizedStringKey("发布新挂单"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTradeBlocked ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
        }
        .disabled(isTradeBlocked)
        .sheet(isPresented: $showCreateSheet) {
            CreateTradeOfferView()
        }
    }
}

#Preview {
    NavigationStack {
        TradeHubView()
    }
}
