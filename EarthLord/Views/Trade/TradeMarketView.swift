//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场页面
//  浏览其他玩家的挂单，搜索和接受交易
//

import SwiftUI
import CoreLocation

struct TradeMarketView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var searchText = ""
    @State private var selectedOffer: TradeOffer?
    @State private var isFirstLoad = true

    // MARK: - 领地距离过滤

    /// 100m 内、允许交易的领地对应的 userId 集合
    private var nearbyTradingOwnerIds: Set<String> {
        guard let userLocation = LocationManager.shared.userLocation else {
            // 未定位时不限制
            return Set(TerritoryManager.shared.territories.map { $0.userId })
        }
        let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        return Set(
            TerritoryManager.shared.territories
                .filter { $0.isActive == true && ($0.allowTrading ?? true) }
                .filter { territory in
                    // 用领地路径点的平均值作为质心
                    let points = territory.path
                    guard !points.isEmpty else { return false }
                    let avgLat = points.compactMap { $0["lat"] }.reduce(0, +) / Double(points.count)
                    let avgLon = points.compactMap { $0["lon"] }.reduce(0, +) / Double(points.count)
                    let centroid = CLLocation(latitude: avgLat, longitude: avgLon)
                    return user.distance(from: centroid) <= 100
                }
                .map { $0.userId }
        )
    }

    /// 筛选后的挂单列表（先过滤距离，再过滤搜索词）
    private var filteredOffers: [TradeOffer] {
        let ownerIds = nearbyTradingOwnerIds
        let nearbyOffers = tradeManager.availableOffers.filter { offer in
            ownerIds.contains(offer.ownerId.uuidString.lowercased()) ||
            ownerIds.contains(offer.ownerId.uuidString)
        }

        guard !searchText.isEmpty else { return nearbyOffers }

        return nearbyOffers.filter { offer in
            let offeringMatch = offer.offeringItems.contains { $0.itemName.localizedCaseInsensitiveContains(searchText) }
            let requestingMatch = offer.requestingItems.contains { $0.itemName.localizedCaseInsensitiveContains(searchText) }
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
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("附近挂单")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(filteredOffers.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            Text("100m 范围内可见")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
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

            Text(searchText.isEmpty ? "附近暂无交易" : "没有找到匹配的挂单")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(searchText.isEmpty ? "靠近其他玩家领地（100m内）可发现挂单" : "尝试更换搜索关键词")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

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
