//
//  PersonalNotificationView.swift
//  EarthLord
//
//  个人通知中心 - 仅自己可见，聚合邮件到期、每日礼包等提醒
//

import SwiftUI

// MARK: - 个人通知类型

enum PersonalNotificationType {
    case dailyGiftReady                         // 每日礼包待领取
    case mailExpiringSoon(mail: Mail, daysLeft: Int) // 邮件即将过期
    case mailUnclaimed(count: Int)              // 有未领取邮件物品
    case taxIncome(count: Int, itemCount: Int)   // 领地税收到账
    case warehouseOverflow                        // 仓库即将满载（预留）

    var icon: String {
        switch self {
        case .dailyGiftReady:           return "gift.fill"
        case .mailExpiringSoon:         return "clock.badge.exclamationmark.fill"
        case .mailUnclaimed:            return "envelope.badge.fill"
        case .taxIncome:                return "flag.fill"
        case .warehouseOverflow:        return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .dailyGiftReady:                          return ApocalypseTheme.warning
        case .mailExpiringSoon(_, let d) where d <= 1: return ApocalypseTheme.danger
        case .mailExpiringSoon:                        return ApocalypseTheme.warning
        case .mailUnclaimed:                           return ApocalypseTheme.info
        case .taxIncome:                               return ApocalypseTheme.primary
        case .warehouseOverflow:                       return ApocalypseTheme.danger
        }
    }

    var title: String {
        switch self {
        case .dailyGiftReady:
            return String(localized: "每日礼包待领取")
        case .mailExpiringSoon(let mail, _):
            return mail.title
        case .mailUnclaimed(let count):
            return String(format: String(localized: "%d 封邮件有待领取物品"), count)
        case .taxIncome(let count, _):
            return String(format: String(localized: "领地税收到账 · %d 笔"), count)
        case .warehouseOverflow:
            return String(localized: "仓库即将满载")
        }
    }

    var subtitle: String {
        switch self {
        case .dailyGiftReady:
            return String(localized: "今日礼包已准备好，前往个人页领取")
        case .mailExpiringSoon(let mail, let days):
            if days == 0 {
                return String(format: String(localized: "今日过期，含 %d 件物品，请尽快领取"), mail.totalItemCount)
            } else {
                return String(format: String(localized: "%d 天后过期，含 %d 件物品，请及时领取"), days, mail.totalItemCount)
            }
        case .mailUnclaimed(let count):
            return String(format: String(localized: "共 %d 封邮件含附件物品，领取至背包或仓库"), count)
        case .taxIncome(_, let itemCount):
            return String(format: String(localized: "共 %d 件物品税收待领取，前往邮箱收取"), itemCount)
        case .warehouseOverflow:
            return String(localized: "仓库容量不足，物品可能无法入库")
        }
    }

    /// 用于排序的优先级（越小越靠前）
    var priority: Int {
        switch self {
        case .mailExpiringSoon(_, let d) where d == 0: return 0
        case .mailExpiringSoon(_, let d) where d == 1: return 1
        case .dailyGiftReady:           return 2
        case .taxIncome:                return 3
        case .mailExpiringSoon:         return 4
        case .mailUnclaimed:            return 5
        case .warehouseOverflow:        return 6
        }
    }
}

// MARK: - 个人通知视图

struct PersonalNotificationView: View {
    @StateObject private var mailboxManager = MailboxManager.shared
    @StateObject private var dailyRewardManager = DailyRewardManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isLoading = true

    private var notifications: [PersonalNotificationType] {
        var result: [PersonalNotificationType] = []

        // 1. 每日礼包（仅订阅用户）
        if subscriptionManager.currentTier != .free && !dailyRewardManager.hasClaimedToday {
            result.append(.dailyGiftReady)
        }

        let unclaimedMails = mailboxManager.mails.filter { !$0.isClaimed && !$0.items.isEmpty && !$0.isExpired }

        // 2. 领地税收到账（taxIncome 类型的未领取邮件）
        let taxMails = unclaimedMails.filter { $0.mailType == .taxIncome }
        if !taxMails.isEmpty {
            let totalItems = taxMails.reduce(0) { $0 + $1.totalItemCount }
            result.append(.taxIncome(count: taxMails.count, itemCount: totalItems))
        }

        // 3. 即将过期的邮件（3天内，排除税收邮件已单独处理）
        let expiringSoon = unclaimedMails
            .filter { $0.mailType != .taxIncome }
            .compactMap { mail -> PersonalNotificationType? in
                guard let days = mail.daysRemaining, days <= 3 else { return nil }
                return .mailExpiringSoon(mail: mail, daysLeft: days)
            }
        result.append(contentsOf: expiringSoon)

        // 4. 其余未领取物品的邮件
        let normalUnclaimed = unclaimedMails.filter { mail in
            guard mail.mailType != .taxIncome else { return false }
            guard let days = mail.daysRemaining else { return true }
            return days > 3
        }
        if !normalUnclaimed.isEmpty {
            result.append(.mailUnclaimed(count: normalUnclaimed.count))
        }

        return result.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(ApocalypseTheme.primary)
                    Text(String(localized: "加载中..."))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else if notifications.isEmpty {
                emptyView
            } else {
                notificationList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "通知"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - 通知列表

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(notifications.enumerated()), id: \.offset) { _, notif in
                    PersonalNotificationCard(notification: notif)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(ApocalypseTheme.success.opacity(0.6))
            Text(String(localized: "暂无待处理通知"))
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(String(localized: "一切都在掌控中"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Methods

    private func loadData() async {
        isLoading = true
        await mailboxManager.loadMails()
        await dailyRewardManager.checkTodayStatus()
        isLoading = false
    }
}

// MARK: - 通知卡片

struct PersonalNotificationCard: View {
    let notification: PersonalNotificationType

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(notification.color.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: notification.icon)
                    .font(.system(size: 20))
                    .foregroundColor(notification.color)
            }

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                Text(notification.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 紧急标记
            if notification.priority <= 1 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.color.opacity(notification.priority <= 1 ? 0.5 : 0.2), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PersonalNotificationView()
    }
}
