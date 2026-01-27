//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  挂单详情页（市场用）
//  显示完整挂单信息，检查库存，接受交易
//

import SwiftUI

struct TradeOfferDetailView: View {
    let offer: TradeOffer

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var isAccepting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var showConfirmAlert = false

    /// 检查库存结果
    private var inventoryCheckResult: CanAcceptTradeResult {
        tradeManager.checkInventory(items: offer.requestingItems)
    }

    /// 是否可以接受交易
    private var canAccept: Bool {
        offer.status == .active && !offer.isExpired && inventoryCheckResult.canAccept && !isAccepting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 发布者信息
                        publisherInfo

                        // 出售物品详情
                        offeringSection

                        // 求购物品详情
                        requestingSection

                        // 留言内容
                        if let message = offer.message, !message.isEmpty {
                            messageSection(message)
                        }

                        // 库存检查提示
                        inventoryCheckSection

                        // 接受交易按钮
                        acceptButton
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("挂单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert("交易失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("交易成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("物品已交换完成！")
            }
            .alert("确认接受交易", isPresented: $showConfirmAlert) {
                Button("确认", role: .destructive) {
                    acceptTrade()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text(confirmMessage)
            }
        }
    }

    /// 确认弹窗消息
    private var confirmMessage: String {
        let giveItems = offer.requestingItems.map { "\($0.itemName) x\($0.quantity)" }.joined(separator: "、")
        let getItems = offer.offeringItems.map { "\($0.itemName) x\($0.quantity)" }.joined(separator: "、")
        return "您将用 \(giveItems) 交换 \(getItems)"
    }

    // MARK: - 发布者信息

    private var publisherInfo: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 50, height: 50)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 用户名和时间
            VStack(alignment: .leading, spacing: 4) {
                Text(offer.ownerUsername)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("发布于 \(formattedDate(offer.createdAt))")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 状态标签
            TradeStatusBadge(status: offer.status)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 出售物品详情

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("出售物品", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Text("\(offer.offeringItems.count) 件")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            VStack(spacing: 8) {
                ForEach(offer.offeringItems) { item in
                    TradeItemRow(item: item)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 求购物品详情

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("求购物品", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Spacer()

                Text("\(offer.requestingItems.count) 件")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            VStack(spacing: 8) {
                ForEach(offer.requestingItems) { item in
                    requestingItemRow(item)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    private func requestingItemRow(_ item: TradeItem) -> some View {
        let available = getAvailableQuantity(for: item)
        let hasEnough = available >= item.quantity

        return HStack(spacing: 12) {
            TradeItemRow(item: item)
                .frame(maxWidth: .infinity)

            // 库存状态
            VStack(alignment: .trailing, spacing: 2) {
                Text("库存: \(available)")
                    .font(.system(size: 11))
                    .foregroundColor(hasEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)

                if !hasEnough {
                    Text("缺少 \(item.quantity - available)")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }
        }
    }

    // MARK: - 留言内容

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("留言", systemImage: "text.bubble")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - 库存检查提示

    private var inventoryCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if inventoryCheckResult.canAccept {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("库存充足，可以接受交易")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("库存不足，无法完成交易")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)
                    }

                    Text("还需要：\(missingItemsText)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 剩余时间
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14))

                Text("剩余时间: \(offer.formattedRemainingTime)")
                    .font(.system(size: 13))
            }
            .foregroundColor(offer.remainingTime < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(inventoryCheckResult.canAccept ? ApocalypseTheme.success.opacity(0.1) : ApocalypseTheme.danger.opacity(0.1))
        )
    }

    private var missingItemsText: String {
        inventoryCheckResult.missingItems.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
    }

    // MARK: - 接受交易按钮

    private var acceptButton: some View {
        Button {
            showConfirmAlert = true
        } label: {
            HStack(spacing: 8) {
                if isAccepting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }

                Text(isAccepting ? "处理中..." : "接受交易")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canAccept ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canAccept)
    }

    // MARK: - 辅助方法

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func getAvailableQuantity(for item: TradeItem) -> Int {
        return inventoryManager.items
            .filter { $0.itemId == item.itemId && $0.quality == item.quality }
            .reduce(0) { $0 + $1.quantity }
    }

    // MARK: - 接受交易

    private func acceptTrade() {
        guard canAccept else { return }

        isAccepting = true

        Task {
            do {
                _ = try await tradeManager.acceptOffer(offerId: offer.id)

                await MainActor.run {
                    showSuccessAlert = true
                    isAccepting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isAccepting = false
                }
            }
        }
    }
}

#Preview {
    let sampleOffer = TradeOffer(
        ownerId: UUID(),
        ownerUsername: "幸存者001",
        offeringItems: [
            TradeItem(itemId: "wood", quantity: 10, quality: nil),
            TradeItem(itemId: "scrap_metal", quantity: 5, quality: nil)
        ],
        requestingItems: [
            TradeItem(itemId: "bandage", quantity: 5, quality: .normal),
            TradeItem(itemId: "medicine", quantity: 2, quality: nil)
        ],
        message: "诚意交换，急需医疗物资！",
        expiresAt: Date().addingTimeInterval(3600 * 12)
    )

    TradeOfferDetailView(offer: sampleOffer)
}
