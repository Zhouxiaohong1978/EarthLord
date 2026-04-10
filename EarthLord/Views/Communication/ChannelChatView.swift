//
//  ChannelChatView.swift
//  EarthLord
//
//  聊天界面 - 频道消息收发
//

import SwiftUI
import Auth
import CoreLocation
import AVFoundation

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

            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(ApocalypseTheme.danger)
                    .onTapGesture { errorMessage = nil }
            }

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

        let filterResult = ContentFilter.check(content)
        guard filterResult.isClean else {
            errorMessage = String(localized: "内容包含违禁词，请修改后重试")
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); errorMessage = nil }
            return
        }

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
            if isOwnMessage { Spacer(minLength: 60) }

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

                // 消息气泡（语音 / 文字）
                if message.isVoice, let voiceUrl = message.voiceUrl {
                    VoiceMessageBubble(
                        voiceUrl: voiceUrl,
                        duration: message.voiceDuration ?? 0,
                        isOwnMessage: isOwnMessage
                    )
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isOwnMessage ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                        .cornerRadius(18)
                }

                // 时间
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            if !isOwnMessage { Spacer(minLength: 60) }
        }
    }
}

// MARK: - VoiceMessageBubble

struct VoiceMessageBubble: View {
    let voiceUrl: String
    let duration: Int
    let isOwnMessage: Bool

    @AppStorage("voiceBroadcastEnabled") private var autoPlay: Bool = false
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var playTimer: Timer?
    @State private var hasAutoPlayed = false

    var body: some View {
        HStack(spacing: 10) {
            // 播放/暂停按钮
            Button(action: togglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.primary)
                    .frame(width: 32, height: 32)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isOwnMessage ? Color.white.opacity(0.3) : ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 3)
                    Capsule()
                        .fill(isOwnMessage ? Color.white : ApocalypseTheme.primary)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

            // 时长
            Text(formatDuration(isPlaying ? Int(progress * Double(duration)) : duration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(isOwnMessage ? .white.opacity(0.8) : ApocalypseTheme.textSecondary)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 160)
        .background(isOwnMessage ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
        .cornerRadius(18)
        .onAppear {
            if autoPlay && !isOwnMessage && !hasAutoPlayed {
                hasAutoPlayed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    togglePlay()
                }
            }
        }
        .onDisappear { stopPlay() }
    }

    private func togglePlay() {
        if isPlaying {
            stopPlay()
        } else {
            startPlay()
        }
    }

    private func startPlay() {
        guard let url = URL(string: voiceUrl) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    try? AVAudioSession.sharedInstance().setCategory(.playback)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    player = try? AVAudioPlayer(data: data)
                    player?.play()
                    isPlaying = true
                    progress = 0

                    playTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        guard let p = player else { return }
                        if p.isPlaying {
                            progress = p.currentTime / p.duration
                        } else {
                            stopPlay()
                        }
                    }
                }
            } catch {
                print("语音播放失败: \(error)")
            }
        }
    }

    private func stopPlay() {
        player?.stop()
        player = nil
        playTimer?.invalidate()
        playTimer = nil
        withAnimation { isPlaying = false; progress = 0 }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
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
