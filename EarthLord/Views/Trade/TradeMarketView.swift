//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场页面
//  浏览其他玩家的挂单，搜索和接受交易
//

import SwiftUI

struct TradeMarketView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var searchText = ""
    @State private var selectedOffer: TradeOffer?
    @State private var isFirstLoad = true

    /// 筛选后的挂单列表
    private var filteredOffers: [TradeOffer] {
        guard !searchText.isEmpty else {
            return tradeManager.availableOffers
        }

        return tradeManager.availableOffers.filter { offer in
            // 搜索出售物品
            let offeringMatch = offer.offeringItems.contains { item in
                item.itemName.localizedCaseInsensitiveContains(searchText)
            }
            // 搜索求购物品
            let requestingMatch = offer.requestingItems.contains { item in
                item.itemName.localizedCaseInsensitiveContains(searchText)
            }
            // 搜索用户名
            let userMatch = offer.ownerUsername.localizedCaseInsensitiveContains(searchText)

            return offeringMatch || requestingMatch || userMatch
        }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 市场统计
                marketStats
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // 挂单列表
                if tradeManager.isLoading && isFirstLoad {
                    loadingState
                } else if filteredOffers.isEmpty {
                    emptyState
                } else {
                    offerList
                        .padding(.top, 12)
                }
            }
        }
        .navigationTitle("交易市场")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        try? await tradeManager.fetchAvailableOffers()
                    }
                } label: {
                    if tradeManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                    }
                }
                .disabled(tradeManager.isLoading)
            }
        }
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer)
        }
        .task {
            if isFirstLoad {
                _ = try? await tradeManager.fetchAvailableOffers()
                isFirstLoad = false
            }
        }
        .refreshable {
            _ = try? await tradeManager.fetchAvailableOffers()
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品或用户...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 市场统计

    private var marketStats: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("可用挂单")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(tradeManager.availableOffers.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            if !searchText.isEmpty && filteredOffers.count != tradeManager.availableOffers.count {
                Text("匹配 \(filteredOffers.count) 个")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredOffers) { offer in
                    TradeOfferCard(offer: offer, showOwnerInfo: true) {
                        selectedOffer = offer
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("加载市场数据...")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: searchText.isEmpty ? "storefront" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(searchText.isEmpty ? "市场暂无挂单" : "没有找到匹配的挂单")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(searchText.isEmpty ? "等待其他玩家发布交易" : "尝试更换搜索关键词")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    NavigationStack {
        TradeMarketView()
    }
}
