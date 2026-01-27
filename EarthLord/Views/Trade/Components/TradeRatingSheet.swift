//
//  TradeRatingSheet.swift
//  EarthLord
//
//  交易评价弹窗
//  5星评分选择 + 评语输入
//

import SwiftUI
import Auth

struct TradeRatingSheet: View {
    let history: TradeHistory
    let onSubmit: (Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 5
    @State private var comment: String = ""

    /// 获取交易对象名称
    private var tradingPartnerName: String {
        guard let userId = AuthManager.shared.currentUser?.id else {
            return "未知用户"
        }
        if history.isSeller(userId: userId) {
            return history.buyerUsername
        } else {
            return history.sellerUsername
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 交易对象信息
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text("评价 \(tradingPartnerName)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(history.formattedCompletedAt)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    // 评分选择
                    VStack(spacing: 12) {
                        Text("交易体验如何？")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        rating = star
                                    }
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundColor(star <= rating ? .yellow : ApocalypseTheme.textMuted)
                                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                                }
                            }
                        }

                        // 评分描述
                        Text(ratingDescription)
                            .font(.system(size: 14))
                            .foregroundColor(ratingColor)
                    }

                    // 评语输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("评语（可选）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextEditor(text: $comment)
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(height: 100)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )

                        Text("\(comment.count)/100")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Spacer()

                    // 提交按钮
                    Button {
                        onSubmit(rating, comment.isEmpty ? nil : comment)
                        dismiss()
                    } label: {
                        Text("提交评价")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.primary)
                            )
                    }
                }
                .padding(24)
            }
            .navigationTitle("交易评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 评分描述

    private var ratingDescription: String {
        switch rating {
        case 1: return "非常不满意"
        case 2: return "不太满意"
        case 3: return "一般"
        case 4: return "满意"
        case 5: return "非常满意"
        default: return ""
        }
    }

    private var ratingColor: Color {
        switch rating {
        case 1, 2: return ApocalypseTheme.danger
        case 3: return ApocalypseTheme.warning
        case 4, 5: return ApocalypseTheme.success
        default: return ApocalypseTheme.textSecondary
        }
    }
}

#Preview {
    let sampleHistory = TradeHistory(
        offerId: UUID(),
        sellerId: UUID(),
        buyerId: UUID(),
        sellerUsername: "幸存者001",
        buyerUsername: "幸存者002",
        itemsExchanged: TradeExchange(
            sellerItems: [TradeItem(itemId: "wood", quantity: 10, quality: nil)],
            buyerItems: [TradeItem(itemId: "bandage", quantity: 5, quality: .normal)]
        )
    )

    TradeRatingSheet(history: sampleHistory) { rating, comment in
        print("Rating: \(rating), Comment: \(comment ?? "无")")
    }
}
