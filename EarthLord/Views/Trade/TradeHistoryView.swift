//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史页面
//  显示已完成的交易记录，支持评价
//

import SwiftUI
import Auth

struct TradeHistoryView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var selectedHistory: TradeHistory?
    @State private var showRatingSheet = false
    @State private var isFirstLoad = true

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.isLoading && isFirstLoad {
                loadingState
            } else if tradeManager.tradeHistory.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("交易历史")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedHistory) { history in
            TradeRatingSheet(history: history) { rating, comment in
                rateHistory(history, rating: rating, comment: comment)
            }
        }
        .task {
            if isFirstLoad {
                _ = try? await tradeManager.fetchTradeHistory()
                isFirstLoad = false
            }
        }
        .refreshable {
            _ = try? await tradeManager.fetchTradeHistory()
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { history in
                    historyCard(history)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 历史卡片

    private func historyCard(_ history: TradeHistory) -> some View {
        let userId = AuthManager.shared.currentUser?.id ?? UUID()
        let isSeller = history.isSeller(userId: userId)
        let partnerName = isSeller ? history.buyerUsername : history.sellerUsername
        let hasRated = history.hasRated(userId: userId)
        let myRating = isSeller ? history.sellerRating : history.buyerRating

        return VStack(alignment: .leading, spacing: 12) {
            // 头部：交易对象和时间
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(partnerName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 角色标签
                    Text(isSeller ? "买家" : "卖家")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ApocalypseTheme.info)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.info.opacity(0.15))
                        )
                }

                Spacer()

                Text(history.formattedCompletedAt)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 给出物品
            itemsSection(
                title: "给出",
                items: isSeller ? history.itemsExchanged.sellerItems : history.itemsExchanged.buyerItems,
                color: ApocalypseTheme.danger
            )

            // 获得物品
            itemsSection(
                title: "获得",
                items: isSeller ? history.itemsExchanged.buyerItems : history.itemsExchanged.sellerItems,
                color: ApocalypseTheme.success
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 评价状态
            HStack {
                if hasRated {
                    // 已评价
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (myRating ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= (myRating ?? 0) ? .yellow : ApocalypseTheme.textMuted)
                        }

                        Text("已评价")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.leading, 4)
                    }
                } else {
                    // 未评价
                    Button {
                        selectedHistory = history
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .font(.system(size: 12))

                            Text("去评价")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)

                Text("交易完成")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 物品区域

    private func itemsSection(title: String, items: [TradeItem], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: title == "给出" ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(color)

            HStack(spacing: 8) {
                ForEach(items) { item in
                    compactItemBadge(item)
                }
            }
        }
    }

    private func compactItemBadge(_ item: TradeItem) -> some View {
        HStack(spacing: 4) {
            Text(item.itemName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("x\(item.quantity)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("加载交易历史...")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无交易记录")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("完成的交易会显示在这里")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 评价交易

    private func rateHistory(_ history: TradeHistory, rating: Int, comment: String?) {
        Task {
            do {
                try await tradeManager.rateTrade(
                    historyId: history.id,
                    rating: rating,
                    comment: comment
                )
            } catch {
                print("评价失败: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        TradeHistoryView()
    }
}
