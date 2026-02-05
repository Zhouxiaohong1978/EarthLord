//
//  ChannelChatView.swift
//  EarthLord
//
//  聊天界面 - 频道消息收发
//

import SwiftUI
import Auth
import CoreLocation

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messageText: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?

    /// 是否可以发送消息
    private var canSend: Bool {
        communicationManager.currentDevice?.canSend ?? false
    }

    /// 当前用户ID
    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    /// 当前频道的消息
    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messageListView

            // 底部输入栏或提示
            bottomBar
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("\(channel.memberCount) 名成员")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .onAppear {
            loadMessages()
            communicationManager.subscribeToChannelMessages(channelId: channel.id)

            // Day 36: 标记频道已读
            if let userId = authManager.currentUser?.id {
                Task {
                    await communicationManager.markChannelAsRead(userId: userId, channelId: channel.id)
                }
            }
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                            .padding(.top, 50)
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId
                            )
                            .id(message.messageId)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("成为第一个发送消息的人")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Group {
            if canSend {
                inputBar
            } else {
                radioModeHint
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("输入消息...", text: $messageText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 发送按钮
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ApocalypseTheme.textSecondary
                        : ApocalypseTheme.primary
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || communicationManager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ApocalypseTheme.cardBackground),
            alignment: .top
        )
    }

    private var radioModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .foregroundColor(ApocalypseTheme.info)
            Text("收音机模式 - 仅可接收消息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ApocalypseTheme.cardBackground),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func loadMessages() {
        Task {
            isLoading = true
            do {
                try await communicationManager.loadChannelMessages(channelId: channel.id)
                errorMessage = nil
                scrollToBottom()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let textToSend = content
        messageText = ""

        // Day 35: 获取真实 GPS 位置
        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        // 🐛 DEBUG: 检查位置数据
        if let lat = latitude, let lon = longitude {
            print("📍 [发送消息] 位置数据: (\(lat), \(lon))")
        } else {
            print("⚠️ [发送消息] 位置数据缺失: location=\(location as Any), lat=\(latitude as Any), lon=\(longitude as Any)")
        }

        Task {
            do {
                try await communicationManager.sendChannelMessage(
                    channelId: channel.id,
                    content: textToSend,
                    latitude: latitude,      // Day 35: 传入位置
                    longitude: longitude     // Day 35: 传入位置
                )
                // 重新加载消息以确保同步
                try await communicationManager.loadChannelMessages(channelId: channel.id)
                scrollToBottom()
            } catch {
                // 恢复消息文本
                messageText = textToSend
                errorMessage = error.localizedDescription
            }
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo(lastMessage.messageId, anchor: .bottom)
            }
        }
    }
}

// MARK: - MessageBubbleView

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 发送者信息（仅他人消息显示）
                if !isOwnMessage {
                    HStack(spacing: 4) {
                        Text(message.senderCallsign ?? "匿名")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        if let deviceType = message.deviceType,
                           let device = DeviceType(rawValue: deviceType) {
                            Image(systemName: device.icon)
                                .font(.caption2)
                                .foregroundColor(device.color)
                        }
                    }
                }

                // 消息气泡
                HStack {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            isOwnMessage
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.cardBackground
                        )
                        .cornerRadius(18)
                }

                // 时间
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChannelChatView(
            channel: CommunicationChannel.preview
        )
        .environmentObject(AuthManager.shared)
    }
}

// MARK: - Preview Helper

extension CommunicationChannel {
    static var preview: CommunicationChannel {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "creator_id": "00000000-0000-0000-0000-000000000002",
            "channel_type": "public",
            "channel_code": "TEST001",
            "name": "测试频道",
            "description": "这是一个测试频道",
            "is_active": true,
            "member_count": 5,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(CommunicationChannel.self, from: json)
    }
}
