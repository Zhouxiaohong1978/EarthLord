//
//  MailDetailView.swift
//  EarthLord
//
//  邮件详情页面
//

import SwiftUI

struct MailDetailView: View {
    let mail: Mail

    @StateObject private var mailboxManager = MailboxManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isClaiming = false
    @State private var claimResult: ClaimResult?
    @State private var showingClaimResult = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 邮件头部
                        mailHeader

                        // 邮件内容
                        if let content = mail.content {
                            mailContent(content)
                        }

                        // 物品列表
                        itemList

                        // 背包容量提示
                        if !mail.isClaimed && !mail.isExpired {
                            backpackCapacityHint
                        }

                        // 领取按钮
                        if !mail.isClaimed && !mail.isExpired {
                            claimButton
                        }

                        // 过期提示
                        if mail.isExpired {
                            expiredNotice
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("邮件详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("领取结果", isPresented: $showingClaimResult) {
                Button("确定") {
                    if claimResult?.isFullyClaimed == true {
                        dismiss()
                    }
                }
            } message: {
                if let result = claimResult {
                    if result.isFullyClaimed {
                        Text("成功领取 \(result.claimedCount) 件物品！")
                    } else {
                        Text("已领取 \(result.claimedCount) 件物品\n背包空间不足，剩余 \(result.remainingCount) 件物品请整理背包后再次领取")
                    }
                }
            }
            .alert("错误", isPresented: .constant(errorMessage != nil)) {
                Button("确定") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            if !mail.isRead {
                Task {
                    await mailboxManager.markAsRead(mail)
                }
            }
        }
    }

    // MARK: - 邮件头部
    private var mailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: mail.mailType.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(mail.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            HStack {
                Text(mail.mailType.displayName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("•")
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(mail.timeAgo)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if let days = mail.daysRemaining {
                    Text("•")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("\(days)天后过期")
                        .font(.caption)
                        .foregroundColor(days <= 7 ? .orange : ApocalypseTheme.textSecondary)
                }
            }

            if mail.isClaimed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已于 \(formatDate(mail.claimedAt)) 领取")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 邮件内容
    private func mailContent(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("邮件内容")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 物品列表
    private var itemList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("附件物品 (\(mail.totalItemCount)件)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(mail.items) { item in
                MailItemCard(item: item)
            }
        }
    }

    // MARK: - 背包容量提示
    private var backpackCapacityHint: some View {
        let currentTypes = InventoryManager.shared.items.count  // 当前物品种类数
        let maxSlots = 100  // 最大格子数
        let remainingSlots = max(0, maxSlots - currentTypes)

        // 计算邮件中有多少种不同物品
        let mailItemTypes = Set(mail.items.map { $0.itemId }).count
        let canClaimAll = mailItemTypes <= remainingSlots

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "backpack.fill")
                    .foregroundColor(canClaimAll ? .green : .orange)
                Text("背包容量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Text("\(currentTypes)/\(maxSlots)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if !canClaimAll {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("背包空间不足，剩余 \(remainingSlots) 个位置，邮件包含 \(mailItemTypes) 种物品")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("背包空间充足，可领取全部物品")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - 领取按钮
    private var claimButton: some View {
        Button(action: {
            Task {
                await claimMail()
            }
        }) {
            HStack {
                if isClaiming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "gift.fill")
                    Text("领取物品")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isClaiming)
    }

    // MARK: - 过期提示
    private var expiredNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("邮件已过期")
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - 方法
    private func claimMail() async {
        isClaiming = true
        defer { isClaiming = false }

        do {
            // 记录领取前的背包状态
            let itemsBeforeClaim = InventoryManager.shared.items.count
            let quantityBeforeClaim = InventoryManager.shared.items.reduce(0) { $0 + $1.quantity }
            print("🔍 [领取前] 背包物品种类: \(itemsBeforeClaim), 总数量: \(quantityBeforeClaim)")

            let result = try await mailboxManager.claimMail(mail)

            // 记录领取后的背包状态
            let itemsAfterClaim = InventoryManager.shared.items.count
            let quantityAfterClaim = InventoryManager.shared.items.reduce(0) { $0 + $1.quantity }
            print("🔍 [领取后] 背包物品种类: \(itemsAfterClaim), 总数量: \(quantityAfterClaim)")
            print("🔍 [变化] 物品种类 +\(itemsAfterClaim - itemsBeforeClaim), 总数量 +\(quantityAfterClaim - quantityBeforeClaim)")
            print("🔍 [RPC返回] 已领取: \(result.claimedCount)件, 剩余: \(result.remainingCount)件")
            print("🔍 [领取详情] \(result.claimedItems.map { "\($0.itemId) x\($0.quantity)" }.joined(separator: ", "))")

            claimResult = result
            showingClaimResult = true
        } catch {
            print("❌ [领取失败] \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 邮件物品卡片

struct MailItemCard: View {
    let item: MailItem

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "cube.box.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Text("数量: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let quality = item.quality {
                        Text("• \(quality)")
                            .font(.caption)
                            .foregroundColor(qualityColor(quality))
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality.lowercased() {
        case "legendary": return .purple
        case "epic": return .orange
        case "rare": return .blue
        case "good": return .green
        default: return ApocalypseTheme.textSecondary
        }
    }
}
