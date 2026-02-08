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

    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Channel list
            if isLoading {
                loadingView
            } else if communicationManager.channelPreviews.isEmpty {
                emptyView
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
            Text("消息")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // Unread badge
            let totalUnread = communicationManager.channelPreviews.reduce(0) { $0 + $1.unreadCount }
            if totalUnread > 0 {
                Text("\(totalUnread) 条未读")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Channel List

    private var channelListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(communicationManager.channelPreviews) { preview in
                    NavigationLink {
                        destinationView(for: preview)
                    } label: {
                        ChannelPreviewRow(preview: preview)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if preview.id != communicationManager.channelPreviews.last?.id {
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
                Text("加载中...")
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
            Text("加载中...")
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

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("订阅频道后消息将显示在这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - Methods

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        do {
            // 确保订阅官方频道
            await communicationManager.ensureOfficialChannelSubscribed(userId: userId)
            // 加载预览
            _ = try await communicationManager.loadChannelPreviews(userId: userId)
            // 同时加载订阅频道（用于导航）
            _ = try await communicationManager.loadSubscribedChannels(userId: userId)

            // 确保官方频道始终显示在列表中
            ensureOfficialChannelInPreviews()
        } catch {
            print("加载消息中心失败: \(error)")
            // 即使加载失败，也确保官方频道显示
            ensureOfficialChannelInPreviews()
        }
        isLoading = false
    }

    /// 确保官方频道始终在预览列表中
    private func ensureOfficialChannelInPreviews() {
        let officialId = CommunicationManager.officialChannelId

        // 检查官方频道是否已在列表中
        if !communicationManager.channelPreviews.contains(where: { $0.channelId == officialId }) {
            // 添加默认的官方频道预览
            let officialPreview = ChannelPreview.officialChannelPreview()
            communicationManager.channelPreviews.insert(officialPreview, at: 0)
        } else {
            // 确保官方频道在列表最前面
            if let index = communicationManager.channelPreviews.firstIndex(where: { $0.channelId == officialId }), index != 0 {
                let preview = communicationManager.channelPreviews.remove(at: index)
                communicationManager.channelPreviews.insert(preview, at: 0)
            }
        }
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
                    Text(preview.channelName)
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
                        Text("暂无消息")
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

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager.shared)
}
