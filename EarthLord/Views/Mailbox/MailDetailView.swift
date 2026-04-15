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
    @StateObject private var warehouseManager = WarehouseManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isClaiming = false
    @State private var isClaimingToWarehouse = false
    @State private var claimResult: ClaimResult?
    @State private var showingClaimResult = false
    @State private var showingWarehouseClaimResult = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirm = false
    @State private var showingPartialClaimConfirm = false

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

                        // 容量提示 + 领取选择
                        if !mail.isClaimed && !mail.isExpired {
                            capacityStatusView
                            claimOptionsView
                        }

                        // 过期提示
                        if mail.isExpired {
                            expiredNotice
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(LocalizedStringKey("邮件详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("关闭")) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert(LocalizedStringKey("删除邮件"), isPresented: $showingDeleteConfirm) {
                Button(LocalizedStringKey("取消"), role: .cancel) {}
                Button(LocalizedStringKey("删除"), role: .destructive) {
                    Task {
                        try? await mailboxManager.deleteMail(mail)
                        dismiss()
                    }
                }
            } message: {
                if mail.isClaimed {
                    Text(LocalizedStringKey("确定删除这封已领取的邮件？"))
                } else {
                    Text(LocalizedStringKey("确定删除这封邮件？未领取的物品将一并删除"))
                }
            }
            .alert(LocalizedStringKey("领取结果"), isPresented: $showingClaimResult) {
                Button(LocalizedStringKey("确定")) {
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
            .alert(LocalizedStringKey("已存入仓库"), isPresented: $showingWarehouseClaimResult) {
                Button(LocalizedStringKey("确定")) { dismiss() }
            } message: {
                Text(LocalizedStringKey("mailbox.claim.warehouse_success"))
            }
            .alert(LocalizedStringKey("错误"), isPresented: .constant(errorMessage != nil)) {
                Button(LocalizedStringKey("确定")) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("背包空间不足", isPresented: $showingPartialClaimConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认领取") {
                    Task { await claimMail() }
                }
            } message: {
                let mailTotal = mail.items.reduce(0) { $0 + $1.quantity }
                let remaining = inventoryManager.remainingCapacity
                Text("背包只能再存入 \(remaining) 件物品，本次只领取 \(remaining) 件，剩余 \(mailTotal - remaining) 件将留在邮件中，整理背包后可继续领取。")
            }
        }
        .onAppear {
            Task {
                if !mail.isRead {
                    await mailboxManager.markAsRead(mail)
                }
                async let _ = warehouseManager.refreshItems()
                async let _ = inventoryManager.refreshInventory()
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

                    Text(String(format: String(localized: "%lld天后过期"), days))
                        .font(.caption)
                        .foregroundColor(days <= 7 ? .orange : ApocalypseTheme.textSecondary)
                }
            }

            if mail.isClaimed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(String(localized: "已于")) \(formatDate(mail.claimedAt)) \(String(localized: "领取"))")
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
            Text(LocalizedStringKey("邮件内容"))
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
            Text("\(String(localized: "附件物品")) (\(mail.totalItemCount)\(String(localized: "件")))")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(mail.items) { item in
                MailItemCard(item: item)
            }
        }
    }

    // MARK: - 容量状态总览
    private var capacityStatusView: some View {
        let mailTotal = mail.items.reduce(0) { $0 + $1.quantity }
        let backpackRemaining = inventoryManager.remainingCapacity
        let warehouseRemaining = warehouseManager.remainingCapacity

        return HStack(spacing: 12) {
            // 背包状态
            capacityCell(
                icon: "backpack.fill",
                label: LocalizedStringKey("mailbox.dest.backpack"),
                used: inventoryManager.totalItemCount,
                total: inventoryManager.backpackCapacity,
                canFit: backpackRemaining >= mailTotal
            )

            // 仓库状态
            if warehouseManager.hasWarehouse {
                capacityCell(
                    icon: "archivebox.fill",
                    label: LocalizedStringKey("mailbox.dest.warehouse"),
                    used: warehouseManager.usedCapacity,
                    total: warehouseManager.totalCapacity,
                    canFit: warehouseRemaining >= mailTotal
                )
            } else {
                noWarehouseCell
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(10)
    }

    private func capacityCell(icon: String, label: LocalizedStringKey, used: Int, total: Int, canFit: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(canFit ? .green : .orange)
                Text(label)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Text("\(used)/\(total)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(canFit ? ApocalypseTheme.textPrimary : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    private var noWarehouseCell: some View {
        VStack(spacing: 4) {
            Image(systemName: "archivebox")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(LocalizedStringKey("mailbox.no_warehouse"))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 领取选择按钮组
    private var claimOptionsView: some View {
        let mailTotal = mail.items.reduce(0) { $0 + $1.quantity }
        let backpackRemaining = inventoryManager.remainingCapacity
        let backpackCanFit = backpackRemaining >= mailTotal
        let backpackHasSomeSpace = backpackRemaining > 0
        let warehouseCanFit = warehouseManager.hasWarehouse && warehouseManager.remainingCapacity >= mailTotal

        return HStack(spacing: 12) {
            // 存入背包
            Button {
                if backpackCanFit {
                    Task { await claimMail() }
                } else {
                    // 部分放得下：弹确认框
                    showingPartialClaimConfirm = true
                }
            } label: {
                HStack(spacing: 6) {
                    if isClaiming {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                    } else {
                        Image(systemName: "backpack.fill")
                    }
                    Text(LocalizedStringKey("mailbox.claim.to_backpack"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    backpackCanFit ? ApocalypseTheme.primary :
                    backpackHasSomeSpace ? Color.orange.opacity(0.8) :
                    Color.gray.opacity(0.4)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isClaiming || isClaimingToWarehouse || !backpackHasSomeSpace)

            // 存入仓库
            Button {
                Task { await claimToWarehouse() }
            } label: {
                HStack(spacing: 6) {
                    if isClaimingToWarehouse {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                    } else {
                        Image(systemName: "archivebox.fill")
                    }
                    Text(LocalizedStringKey("mailbox.claim.to_warehouse"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(warehouseCanFit ? Color(red: 0.2, green: 0.5, blue: 0.3) : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isClaiming || isClaimingToWarehouse || !warehouseCanFit)
        }
    }

    // MARK: - 背包容量提示（保留兼容）
    private var backpackCapacityHint: some View {
        let currentCount = inventoryManager.totalItemCount  // 当前物品总数量
        let maxSlots = inventoryManager.backpackCapacity  // 基于订阅档位动态获取
        let remainingSlots = max(0, maxSlots - currentCount)

        // 计算邮件中物品总数量
        let mailItemCount = mail.items.reduce(0) { $0 + $1.quantity }
        let canClaimAll = mailItemCount <= remainingSlots

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "backpack.fill")
                    .foregroundColor(canClaimAll ? .green : .orange)
                Text(LocalizedStringKey("背包容量"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Text("\(currentCount)/\(maxSlots)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if !canClaimAll {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(LocalizedStringKey("背包空间不足，剩余 \(remainingSlots) 个位置，邮件包含 \(mailItemCount) 件物品"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("背包空间充足，可领取全部物品"))
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
                    Text(LocalizedStringKey("领取物品"))
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
            Text(LocalizedStringKey("邮件已过期"))
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

    private func claimToWarehouse() async {
        isClaimingToWarehouse = true
        defer { isClaimingToWarehouse = false }
        do {
            try await mailboxManager.claimMailToWarehouse(mail)
            showingWarehouseClaimResult = true
        } catch {
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
                Text(resourceDisplayName(for: item.itemId))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(String(format: String(localized: "数量: %d"), item.quantity))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let quality = item.quality {
                        let displayQuality = ItemQuality(rawValue: quality)?.displayName ?? quality
                        Text("• \(displayQuality)")
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
