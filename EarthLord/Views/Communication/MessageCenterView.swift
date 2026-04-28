//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心 - Day 36 实现
//  类似微信消息列表，显示所有订阅频道
//

import SwiftUI
import Auth

struct MessageCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @StateObject private var mailboxManager = MailboxManager.shared
    @StateObject private var dailyRewardManager = DailyRewardManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isLoading = true
    @State private var isPublicChannelExpanded = false

    /// 未处理的个人通知数量（用于角标）
    private var personalNotificationCount: Int {
        var count = 0
        if subscriptionManager.currentTier != .free && !dailyRewardManager.hasClaimedToday { count += 1 }
        let unclaimed = mailboxManager.mails.filter { !$0.isClaimed && !$0.items.isEmpty && !$0.isExpired }
        // 税收到账（按笔数计）
        count += unclaimed.filter { $0.mailType == .taxIncome }.count
        // 即将过期（非税收）
        count += unclaimed.filter { $0.mailType != .taxIncome }.compactMap { $0.daysRemaining }.filter { $0 <= 3 }.count
        // 普通未领取
        if !unclaimed.filter({ $0.mailType != .taxIncome && ($0.daysRemaining ?? 99) > 3 }).isEmpty { count += 1 }
        return count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Channel list（通知行始终显示）
            if isLoading {
                loadingView
            } else {
                channelListView
            }
        }
        .background(ApocalypseTheme.background)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(String(localized: "消息"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // Unread badge
            let totalUnread = communicationManager.channelPreviews.reduce(0) { $0 + $1.unreadCount }
            if totalUnread > 0 {
                Text(String(format: String(localized: "%d 条未读"), totalUnread))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Channel List

    /// 官方频道（单独置顶）
    private var officialPreviews: [ChannelPreview] {
        communicationManager.channelPreviews.filter { $0.isOfficial }
    }

    /// 所有非官方频道，按最新消息时间倒序（归入公共频道分区）
    private var allChannelPreviews: [ChannelPreview] {
        communicationManager.channelPreviews
            .filter { !$0.isOfficial }
            .sorted {
                let a = $0.lastMessageTime ?? Date.distantPast
                let b = $1.lastMessageTime ?? Date.distantPast
                return a > b
            }
    }

    /// 公共频道分区总未读数
    private var publicTotalUnread: Int {
        allChannelPreviews.reduce(0) { $0 + $1.unreadCount }
    }

    /// 已收藏的频道预览
    private var favoritedPreviews: [ChannelPreview] {
        communicationManager.channelPreviews.filter {
            communicationManager.isFavorited(channelId: $0.channelId) && !$0.isOfficial
        }
    }

    private var channelListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 个人通知入口（始终置顶）
                NavigationLink {
                    PersonalNotificationView()
                        .environmentObject(authManager)
                } label: {
                    PersonalNotificationRow(badgeCount: personalNotificationCount)
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .background(ApocalypseTheme.cardBackground)
                    .padding(.leading, 72)

                // 官方频道（可展开）
                if let official = officialPreviews.first {
                    officialRow(preview: official)
                }

                // 公共频道 · LIVE 分区（所有非官方频道）
                publicLiveSection

                // 收藏频道分区
                favoritedSection
            }
        }
    }

    // MARK: - 官方消息入口（直接导航）

    @ViewBuilder
    private func officialRow(preview: ChannelPreview) -> some View {
        NavigationLink {
            OfficialChannelDetailView()
                .environmentObject(authManager)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "末日官方广播"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    HStack(spacing: 4) {
                        Text(String(localized: "官方消息"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        if preview.unreadCount > 0 {
                            Text(String(format: String(localized: "%d 条未读消息"), preview.unreadCount))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.primary)
                        } else {
                            Text(String(localized: "0 条消息"))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.background)
        }
        .buttonStyle(PlainButtonStyle())

        Divider()
            .background(ApocalypseTheme.cardBackground)
            .padding(.leading, 72)
    }

    // MARK: - 公共频道 · LIVE

    private var publicChannelCount: Int {
        communicationManager.channels.filter { $0.channelType == .public }.count
    }

    private var publicLiveSection: some View {
        VStack(spacing: 0) {
            // 卡片头部（点击展开/折叠）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPublicChannelExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        // 图标
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.info.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 22))
                                .foregroundColor(ApocalypseTheme.info)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            // 标题行
                            HStack(spacing: 6) {
                                Text(String(localized: "公共频道"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                // LIVE 标签
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 5, height: 5)
                                    Text("LIVE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                            }

                            // 描述文字（始终显示）
                            Text(String(localized: "升级你的设备以接收和发送消息"))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        Spacer()

                        // 展开/折叠箭头
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .rotationEffect(.degrees(isPublicChannelExpanded ? 90 : 0))
                    }

                    // 未读消息数（始终显示）
                    HStack(spacing: 6) {
                        if publicTotalUnread > 0 {
                            Text("\(publicTotalUnread > 99 ? "99+" : "\(publicTotalUnread)")")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        Text(publicTotalUnread > 0
                             ? String(format: String(localized: "%d 条未读消息"), publicTotalUnread)
                             : String(localized: "0 条消息"))
                            .font(.caption2)
                            .foregroundColor(publicTotalUnread > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }
                    .padding(.leading, 62)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.background)
            }
            .buttonStyle(PlainButtonStyle())

            // 展开后显示所有频道，按最新消息倒序
            if isPublicChannelExpanded {
                Divider()
                    .background(ApocalypseTheme.cardBackground)
                    .padding(.leading, 72)

                if allChannelPreviews.isEmpty {
                    Text(String(localized: "暂无消息"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.background)
                } else {
                    ForEach(allChannelPreviews) { preview in
                        NavigationLink {
                            destinationView(for: preview)
                        } label: {
                            ChannelPreviewRow(preview: preview)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .background(ApocalypseTheme.cardBackground)
                            .padding(.leading, 72)
                    }
                }
            } else {
                Divider()
                    .background(ApocalypseTheme.cardBackground)
                    .padding(.leading, 72)
            }
        }
    }

    // MARK: - 收藏频道

    private var favoritedSection: some View {
        VStack(spacing: 0) {
            // 分区标题
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)

                Text(String(localized: "收藏频道"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(favoritedPreviews.count)")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if favoritedPreviews.isEmpty {
                // 空状态
                HStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(String(localized: "在频道中心点击 ★ 收藏频道"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ApocalypseTheme.background)
            } else {
                ForEach(favoritedPreviews) { preview in
                    NavigationLink {
                        destinationView(for: preview)
                    } label: {
                        ChannelPreviewRow(preview: preview)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if preview.id != favoritedPreviews.last?.id {
                        Divider()
                            .background(ApocalypseTheme.cardBackground)
                            .padding(.leading, 72)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for preview: ChannelPreview) -> some View {
        if preview.isOfficial {
            OfficialChannelDetailView()
                .environmentObject(authManager)
        } else {
            // 查找完整频道对象
            if let channel = communicationManager.subscribedChannels.first(where: { $0.channel.id == preview.channelId })?.channel {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            } else {
                // Fallback - 重新加载
                Text(String(localized: "加载中..."))
                    .task {
                        if let userId = authManager.currentUser?.id {
                            _ = try? await communicationManager.loadSubscribedChannels(userId: userId)
                        }
                    }
            }
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text(String(localized: "加载中..."))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(String(localized: "暂无消息"))
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(String(localized: "订阅频道后消息将显示在这里"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - Methods

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        // 同步通知相关状态，确保角标数量准确
        await dailyRewardManager.checkTodayStatus()
        await mailboxManager.loadMails()
        do {
            // 确保订阅官方频道
            await communicationManager.ensureOfficialChannelSubscribed(userId: userId)
            // 加载预览
            _ = try await communicationManager.loadChannelPreviews(userId: userId)
            // 同时加载订阅频道（用于导航）
            _ = try await communicationManager.loadSubscribedChannels(userId: userId)

            // 确保官方频道始终显示在列表中，并更新真实未读数
            await ensureOfficialChannelInPreviews(userId: userId)
        } catch {
            print("加载消息中心失败: \(error)")
            await ensureOfficialChannelInPreviews(userId: userId)
        }
        isLoading = false
    }

    /// 确保官方频道始终在预览列表中，并同步真实未读数
    private func ensureOfficialChannelInPreviews(userId: UUID? = nil) async {
        let officialId = CommunicationManager.officialChannelId
        let unreadCount = userId != nil ? (try? await communicationManager.fetchOfficialChannelUnreadCount(userId: userId!)) ?? 0 : 0

        if let index = communicationManager.channelPreviews.firstIndex(where: { $0.channelId == officialId }) {
            // 已在列表中：更新未读数并移到最前
            var preview = communicationManager.channelPreviews.remove(at: index)
            if unreadCount > 0 { preview = preview.withUnreadCount(unreadCount) }
            communicationManager.channelPreviews.insert(preview, at: 0)
        } else {
            // 不在列表中：创建默认预览并插入
            var officialPreview = ChannelPreview.officialChannelPreview()
            if unreadCount > 0 { officialPreview = officialPreview.withUnreadCount(unreadCount) }
            communicationManager.channelPreviews.insert(officialPreview, at: 0)
        }
    }
}

// MARK: - Personal Notification Row

struct PersonalNotificationRow: View {
    let badgeCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.warning.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "bell.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.warning)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(localized: "通知"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }
                Text(badgeCount > 0
                     ? String(format: String(localized: "%d 条待处理提醒"), badgeCount)
                     : String(localized: "暂无待处理提醒"))
                    .font(.caption)
                    .foregroundColor(badgeCount > 0 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
            }

            if badgeCount > 0 {
                Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Channel Preview Row

struct ChannelPreviewRow: View {
    let preview: ChannelPreview

    private var iconColor: Color {
        preview.isOfficial ? ApocalypseTheme.primary : preview.type.color
    }

    var body: some View {
        HStack(spacing: 12) {
            // Channel icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: preview.isOfficial ? "megaphone.fill" : preview.type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }

            // Channel info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(preview.isOfficial ? String(localized: "末日广播站") : preview.channelName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if preview.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    Spacer()

                    // Time
                    Text(preview.formattedTime)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                HStack {
                    // Last message preview
                    if let content = preview.lastMessageContent {
                        if let sender = preview.lastMessageSender {
                            Text("\(sender): \(content)")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text(content)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(String(localized: "暂无消息"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()

                    // Unread badge
                    if preview.unreadCount > 0 {
                        Text(preview.unreadCount > 99 ? "99+" : "\(preview.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(preview.isMuted ? ApocalypseTheme.textSecondary : Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 公共频道列表 Sheet

struct PublicChannelsListSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChannel: CommunicationChannel?

    private var publicChannels: [CommunicationChannel] {
        communicationManager.channels.filter { $0.channelType == .public }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                if publicChannels.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "globe.americas")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(String(localized: "暂无公共频道"))
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(localized: "前往频道中心创建公共频道"))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(publicChannels) { channel in
                                let isSubscribed = communicationManager.isSubscribed(channelId: channel.id)
                                ChannelRowView(channel: channel, isSubscribed: isSubscribed, isOfficial: false)
                                    .onTapGesture { selectedChannel = channel }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(String(localized: "公共频道"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "关闭")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager.shared)
}
