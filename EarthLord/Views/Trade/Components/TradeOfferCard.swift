//
//  TradeOfferCard.swift
//  EarthLord
//
//  挂单卡片组件
//  卡片式布局显示挂单信息
//

import SwiftUI

struct TradeOfferCard: View {
    let offer: TradeOffer
    var showOwnerInfo: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：用户名 + 状态标签
                header

                // 内容：出售物品 ↔ 求购物品
                content

                // 底部：剩余时间 + 留言
                footer
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            if showOwnerInfo {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(offer.ownerUsername)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            Spacer()

            TradeStatusBadge(status: offer.status)
        }
    }

    // MARK: - 内容

    private var content: some View {
        HStack(spacing: 12) {
            // 出售物品
            VStack(alignment: .leading, spacing: 6) {
                Label("出售", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ApocalypseTheme.success)

                ForEach(offer.offeringItems.prefix(3)) { item in
                    compactItemRow(item)
                }

                if offer.offeringItems.count > 3 {
                    Text("等 \(offer.offeringItems.count) 件物品")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 交换图标
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)

            // 求购物品
            VStack(alignment: .trailing, spacing: 6) {
                Label("求购", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ApocalypseTheme.info)

                ForEach(offer.requestingItems.prefix(3)) { item in
                    compactItemRow(item, alignment: .trailing)
                }

                if offer.requestingItems.count > 3 {
                    Text("等 \(offer.requestingItems.count) 件物品")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - 紧凑物品行

    private func compactItemRow(_ item: TradeItem, alignment: HorizontalAlignment = .leading) -> some View {
        HStack(spacing: 4) {
            if alignment == .trailing {
                Spacer(minLength: 0)
            }

            Text(item.itemName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("x\(item.quantity)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)

            if alignment == .leading {
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 剩余时间（仅在活跃状态显示）
                if offer.status == .active {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))

                        Text(offer.formattedRemainingTime)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(offer.remainingTime < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 留言（如有）
                if let message = offer.message, !message.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 11))

                        Text(message)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            // 已完成时显示接受者信息
            if offer.status == .completed, let acceptedBy = offer.completedByUsername {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.checkmark")
                        .font(.system(size: 11))

                    Text("由 \(acceptedBy) 接受")
                        .font(.system(size: 12))

                    if let completedAt = offer.completedAt {
                        Text("· \(formattedDate(completedAt))")
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(ApocalypseTheme.info)
            }
        }
    }

    // MARK: - 辅助方法

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
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
            TradeItem(itemId: "bandage", quantity: 5, quality: .normal)
        ],
        message: "诚意交换，先到先得",
        expiresAt: Date().addingTimeInterval(3600 * 12)
    )

    VStack(spacing: 16) {
        TradeOfferCard(offer: sampleOffer)

        TradeOfferCard(offer: sampleOffer, showOwnerInfo: true)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
