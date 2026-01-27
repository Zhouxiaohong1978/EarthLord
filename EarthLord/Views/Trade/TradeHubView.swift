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
                                title: "交易市场",
                                subtitle: "浏览其他玩家的挂单",
                                icon: "storefront.fill",
                                iconColor: ApocalypseTheme.primary,
                                count: tradeManager.availableOffers.count,
                                countLabel: "可用挂单"
                            )
                        }

                        // 我的挂单
                        NavigationLink {
                            MyTradeOffersView()
                        } label: {
                            entryCard(
                                title: "我的挂单",
                                subtitle: "管理您发布的挂单",
                                icon: "list.bullet.rectangle.fill",
                                iconColor: ApocalypseTheme.info,
                                count: activeOffersCount,
                                countLabel: "进行中"
                            )
                        }

                        // 交易历史
                        NavigationLink {
                            TradeHistoryView()
                        } label: {
                            entryCard(
                                title: "交易历史",
                                subtitle: "查看已完成的交易",
                                icon: "clock.arrow.circlepath",
                                iconColor: ApocalypseTheme.success,
                                count: tradeManager.tradeHistory.count,
                                countLabel: "笔交易"
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
        .navigationTitle("交易中心")
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

    private var headerStats: some View {
        HStack(spacing: 16) {
            statItem(
                value: "\(tradeManager.availableOffers.count)",
                label: "市场挂单",
                icon: "cart.fill",
                color: ApocalypseTheme.primary
            )

            statItem(
                value: "\(activeOffersCount)",
                label: "我的挂单",
                icon: "tag.fill",
                color: ApocalypseTheme.info
            )

            statItem(
                value: "\(tradeManager.tradeHistory.count)",
                label: "交易次数",
                icon: "arrow.left.arrow.right",
                color: ApocalypseTheme.success
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 入口卡片

    private func entryCard(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        count: Int,
        countLabel: String
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

    private var quickPublishButton: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))

                Text("发布新挂单")
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
