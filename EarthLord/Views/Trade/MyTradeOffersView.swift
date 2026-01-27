//
//  MyTradeOffersView.swift
//  EarthLord
//
//  我的挂单页面
//  显示用户发布的所有挂单，支持筛选和取消
//

import SwiftUI

/// 挂单筛选类型
enum TradeOfferFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case active = "挂单中"
    case completed = "已完成"
    case cancelled = "已取消"
    case expired = "已过期"

    var id: String { rawValue }

    /// 对应的状态
    var status: TradeOfferStatus? {
        switch self {
        case .all: return nil
        case .active: return .active
        case .completed: return .completed
        case .cancelled: return .cancelled
        case .expired: return .expired
        }
    }
}

struct MyTradeOffersView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var selectedFilter: TradeOfferFilter = .all
    @State private var showCreateSheet = false
    @State private var showCancelAlert = false
    @State private var offerToCancel: TradeOffer?
    @State private var isFirstLoad = true

    /// 筛选后的挂单列表
    private var filteredOffers: [TradeOffer] {
        guard let status = selectedFilter.status else {
            return tradeManager.myOffers
        }
        return tradeManager.myOffers.filter { $0.status == status }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 筛选栏
                filterBar
                    .padding(.top, 8)

                // 挂单列表
                if tradeManager.isLoading && isFirstLoad {
                    loadingState
                } else if filteredOffers.isEmpty {
                    emptyState
                } else {
                    offerList
                }
            }
        }
        .navigationTitle("我的挂单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTradeOfferView()
        }
        .alert("取消挂单", isPresented: $showCancelAlert) {
            Button("确定取消", role: .destructive) {
                cancelOffer()
            }
            Button("返回", role: .cancel) { }
        } message: {
            Text("取消后，出售物品将退还到您的背包")
        }
        .task {
            if isFirstLoad {
                _ = try? await tradeManager.fetchMyOffers()
                await tradeManager.checkAndExpireOffers()
                isFirstLoad = false
            }
        }
        .refreshable {
            _ = try? await tradeManager.fetchMyOffers()
            await tradeManager.checkAndExpireOffers()
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TradeOfferFilter.allCases) { filter in
                    filterButton(filter)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterButton(_ filter: TradeOfferFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countOffers(for: filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white : ApocalypseTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? ApocalypseTheme.primary.opacity(0.3) : ApocalypseTheme.background)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
    }

    private func countOffers(for filter: TradeOfferFilter) -> Int {
        guard let status = filter.status else {
            return tradeManager.myOffers.count
        }
        return tradeManager.myOffers.filter { $0.status == status }.count
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredOffers) { offer in
                    offerRow(offer)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func offerRow(_ offer: TradeOffer) -> some View {
        TradeOfferCard(offer: offer)
            .contextMenu {
                if offer.status == .active {
                    Button(role: .destructive) {
                        offerToCancel = offer
                        showCancelAlert = true
                    } label: {
                        Label("取消挂单", systemImage: "xmark.circle")
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if offer.status == .active {
                    Button(role: .destructive) {
                        offerToCancel = offer
                        showCancelAlert = true
                    } label: {
                        Label("取消", systemImage: "xmark.circle")
                    }
                }
            }
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(emptyStateTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(emptyStateSubtitle)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            if selectedFilter == .all {
                Button {
                    showCreateSheet = true
                } label: {
                    Text("发布第一个挂单")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary)
                        )
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "还没有挂单"
        case .active: return "没有进行中的挂单"
        case .completed: return "没有已完成的挂单"
        case .cancelled: return "没有已取消的挂单"
        case .expired: return "没有已过期的挂单"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all: return "发布挂单，与其他玩家交换物资"
        case .active: return "您可以发布新的挂单"
        case .completed: return "完成的交易会显示在这里"
        case .cancelled: return "取消的挂单会显示在这里"
        case .expired: return "过期的挂单会显示在这里"
        }
    }

    // MARK: - 取消挂单

    private func cancelOffer() {
        guard let offer = offerToCancel else { return }

        Task {
            do {
                try await tradeManager.cancelOffer(offerId: offer.id)
            } catch {
                print("取消挂单失败: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyTradeOffersView()
    }
}
