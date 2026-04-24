//
//  ChannelChatView.swift
//  EarthLord
//
//  聊天界面 - 频道消息收发
//

import SwiftUI
import Auth
import CoreLocation
import MapKit
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
                            if message.messageType == .system {
                                SystemMessageBubble(message: message)
                                    .id(message.messageId)
                            } else {
                                MessageBubbleView(
                                    message: message,
                                    isOwnMessage: message.senderId == currentUserId
                                )
                                .id(message.messageId)
                            }
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
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "radio")
                    .foregroundColor(ApocalypseTheme.info)
                Text("收音机模式 - 仅可接收消息")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Text("请尽快升级对讲机才能与周围3公里的其他玩家交流")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.warning)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
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
                    Text(message.localizedContent)
                        .font(.body)
                        .foregroundColor(isOwnMessage ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isOwnMessage ? Color(red: 0.18, green: 0.72, blue: 0.35) : .white)
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

// MARK: - 系统消息气泡（探索分享、挂单推送等）

struct SystemMessageBubble: View {
    let message: ChannelMessage

    private var isExploration: Bool {
        message.localizedContent.contains("探索发现") ||
        message.localizedContent.contains("Exploration") ||
        message.localizedContent.contains("Discovery")
    }

    private var isTrade: Bool {
        message.localizedContent.contains("挂单") || message.localizedContent.contains("Trade")
    }

    private var accentColor: Color {
        if isExploration { return ApocalypseTheme.primary }
        if isTrade { return ApocalypseTheme.info }
        return ApocalypseTheme.textSecondary
    }

    private var iconName: String {
        if isExploration { return "mappin.circle.fill" }
        if isTrade { return "tag.circle.fill" }
        return "info.circle.fill"
    }

    private var typeLabel: String {
        if isExploration { return String(localized: "探索发现") }
        if isTrade { return String(localized: "交易情报") }
        return String(localized: "系统消息")
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    // 标题行
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                        Text(typeLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    Divider()
                        .background(accentColor.opacity(0.25))
                        .padding(.horizontal, 12)

                    // 消息正文
                    Text(message.localizedContent)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textPrimary.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // 坐标跳转按钮（始终显示，有坐标时跳转地图）
                    if isExploration || isTrade {
                        Divider()
                            .background(accentColor.opacity(0.25))
                            .padding(.horizontal, 12)

                        Button {
                            if let loc = message.senderLocation {
                                openInMaps(lat: loc.latitude, lon: loc.longitude)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                Text(message.senderLocation != nil ? String(localized: "查看坐标") : String(localized: "坐标已共享"))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(message.senderLocation != nil ? accentColor : ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .disabled(message.senderLocation == nil)
                    }
                }
                .frame(maxWidth: 280)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
                Spacer()
            }

            Text(message.timeAgo)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private func openInMaps(lat: Double, lon: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = typeLabel
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        ])
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
    @State private var playTimer: Timer?
    @State private var hasAutoPlayed = false
    @State private var waveOpacity: Double = 1.0
    @State private var waveTimer: Timer?
    /// 他人语音：未播放前显示红点
    @State private var isUnread: Bool

    init(voiceUrl: String, duration: Int, isOwnMessage: Bool) {
        self.voiceUrl = voiceUrl
        self.duration = duration
        self.isOwnMessage = isOwnMessage
        self._isUnread = State(initialValue: !isOwnMessage)
    }

    /// 气泡宽度随时长线性增长（微信风格），最小80，最大220
    private var bubbleWidth: CGFloat {
        min(80 + CGFloat(min(duration, 60)) * 2.2, 220)
    }

    /// 时长文字：秒数 + 双引号，如 "3""
    private var durationLabel: String { "\(duration)\"" }

    var body: some View {
        HStack(spacing: 6) {
            // 气泡主体
            Button(action: { isUnread = false; togglePlay() }) {
                HStack(spacing: 8) {
                    if isOwnMessage {
                        // 自己：时长在左，波纹在右（微信镜像）
                        Text(durationLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(waveOpacity)
                            .scaleEffect(x: -1)
                    } else {
                        // 他人：波纹在左，时长在右
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .opacity(waveOpacity)
                        Text(durationLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minWidth: bubbleWidth)
                .background(isOwnMessage ? Color(red: 0.18, green: 0.72, blue: 0.35) : Color.white)
                .cornerRadius(18)
            }
            .buttonStyle(.plain)
            .fixedSize()

            // 未读红点（气泡外侧，仅他人消息）
            if !isOwnMessage && isUnread {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            if autoPlay && !isOwnMessage && !hasAutoPlayed {
                hasAutoPlayed = true
                isUnread = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { togglePlay() }
            }
        }
        .onDisappear { stopPlay() }
    }

    private func togglePlay() {
        if isPlaying { stopPlay() } else { startPlay() }
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
                    // 波纹脉冲动画
                    waveOpacity = 1.0
                    waveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            waveOpacity = waveOpacity > 0.4 ? 0.3 : 1.0
                        }
                    }
                    // 播放结束检测 timer
                    playTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        guard let p = player else { return }
                        if !p.isPlaying { stopPlay() }
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
        playTimer?.invalidate(); playTimer = nil
        waveTimer?.invalidate(); waveTimer = nil
        isPlaying = false
        waveOpacity = 1.0
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
