//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场页面
//  浏览其他玩家的挂单，搜索和接受交易
//

import SwiftUI

// MARK: - 交易市场分类筛选

enum TradeMarketFilter: CaseIterable, Identifiable {
    case all, equipment, blueprint, material, food, medical, tool

    var id: String { title }

    var title: String {
        switch self {
        case .all:       return String(localized: "全部")
        case .equipment: return String(localized: "装备")
        case .blueprint: return String(localized: "图纸")
        case .material:  return String(localized: "材料")
        case .food:      return String(localized: "食物")
        case .medical:   return String(localized: "医疗")
        case .tool:      return String(localized: "工具")
        }
    }

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2.fill"
        case .equipment: return "shield.fill"
        case .blueprint: return "doc.badge.gearshape.fill"
        case .material:  return "cube.fill"
        case .food:      return "fork.knife"
        case .medical:   return "cross.case.fill"
        case .tool:      return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .all:       return ApocalypseTheme.primary
        case .equipment: return .purple
        case .blueprint: return .blue
        case .material:  return .brown
        case .food:      return .orange
        case .medical:   return .red
        case .tool:      return .gray
        }
    }

    /// 该分类包含的 itemId 关键词
    var itemIds: Set<String> {
        switch self {
        case .all:       return []
        case .equipment: return ["equipment_rare", "equipment_epic"]
        case .blueprint: return ["blueprint_basic", "blueprint_epic"]
        case .material:  return ["wood", "stone", "scrap_metal", "glass", "cloth", "nails",
                                  "rope", "seeds", "fuel", "electronic_component", "satellite_module"]
        case .food:      return ["bread", "hardtack", "canned_food", "juice", "grain",
                                  "vegetable", "fruit", "water_bottle"]
        case .medical:   return ["bandage", "medicine", "first_aid_kit", "antibiotics"]
        case .tool:      return ["tool", "toolbox", "build_speedup", "flashlight",
                                  "backpack_expand_voucher"]
        }
    }

    func matches(_ offer: TradeOffer) -> Bool {
        guard self != .all else { return true }
        let allItems = offer.offeringItems + offer.requestingItems
        return allItems.contains { item in
            if !itemIds.isEmpty { return itemIds.contains(item.itemId) }
            // 装备分类额外通过 ItemCategory 匹配
            let def = MockExplorationData.getItemDefinition(by: item.itemId)
            return def?.category == .equipment
        }
    }
}

struct TradeMarketView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var searchText = ""
    @State private var selectedFilter: TradeMarketFilter = .all
    @State private var selectedOffer: TradeOffer?
    @State private var isFirstLoad = true

    /// 进入对方领地触发时传入：只显示该领地主人的挂单（nil = 全局市场）
    var filterUserId: UUID?

    /// 筛选后的挂单列表
    private var filteredOffers: [TradeOffer] {
        // 先按领地主人过滤（若有）
        let base: [TradeOffer]
        if let uid = filterUserId {
            base = tradeManager.availableOffers.filter { $0.ownerId == uid }
        } else {
            base = tradeManager.availableOffers
        }
        // 按分类筛选
        let categorized = selectedFilter == .all ? base : base.filter { selectedFilter.matches($0) }
        // 再按搜索词过滤
        guard !searchText.isEmpty else { return categorized }
        return categorized.filter { offer in
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

                // 分类筛选
                filterChips
                    .padding(.top, 10)

                // 市场统计
                marketStats
                    .padding(.top, 10)
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

    // MARK: - 分类筛选

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TradeMarketFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11))
                            Text(filter.title)
                                .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                        }
                        .foregroundColor(selectedFilter == filter ? .white : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selectedFilter == filter ? filter.color : ApocalypseTheme.cardBackground)
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedFilter == filter ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 市场统计

    private var marketStats: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: filterUserId != nil ? "mappin.and.ellipse" : "storefront.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(LocalizedStringKey(filterUserId != nil ? "trade.nearby.listings" : "全球挂单"))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(filteredOffers.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            Text(LocalizedStringKey(filterUserId != nil ? "trade.nearby.hint" : "所有玩家挂单可见"))
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

            Text(searchText.isEmpty ? "暂无挂单" : "没有找到匹配的挂单")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(searchText.isEmpty ? "目前没有其他玩家挂单，稍后再来看看" : "尝试更换搜索关键词")
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
