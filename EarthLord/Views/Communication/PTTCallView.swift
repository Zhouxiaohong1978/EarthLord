//
//  PTTCallView.swift
//  EarthLord
//
//  PTT通话界面 - Day 36 实现
//  类似对讲机的按住说话界面
//

import SwiftUI

struct PTTCallView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isPressing = false
    @State private var messageText = ""
    @State private var isEmergencyMode = false
    @State private var showQuickMessages = false
    @State private var isSending = false
    @State private var showSentFeedback = false
    @State private var sentMessage: String?
    @State private var showChannelPicker = false
    @State private var sentToChannel: String?
    @State private var navigateToChannel: CommunicationChannel?

    // Quick message templates
    private let quickMessages = [
        "收到，明白",
        "需要支援",
        "发现资源",
        "位置安全",
        "正在撤离",
        "保持静默"
    ]

    /// 可选择的目标频道（排除官方频道）
    private var availableChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.filter {
            !communicationManager.isOfficialChannel($0.channel.id)
        }
    }

    /// 当前目标频道
    private var targetChannel: (id: UUID, name: String)? {
        communicationManager.getPTTTargetChannel()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with device info
            headerView

            Spacer()

            // Status display
            statusDisplay

            Spacer()

            // PTT button area
            pttButtonArea

            // Quick messages
            quickMessageBar

            // Emergency toggle
            emergencyToggle
        }
        .padding(.bottom, 20)
        .background(ApocalypseTheme.background)
        .overlay {
            // Sent feedback overlay
            if showSentFeedback, let msg = sentMessage {
                sentFeedbackOverlay(msg)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { navigateToChannel != nil },
            set: { if !$0 { navigateToChannel = nil } }
        )) {
            if let channel = navigateToChannel {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("PTT 通话")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if let device = communicationManager.currentDevice {
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.iconName)
                    Text(device.deviceType.displayName)
                    Text("·")
                    Text("覆盖 \(device.deviceType.rangeText)")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // Callsign
            if let callsign = communicationManager.userCallsign {
                Text("呼号: \(callsign)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.top, 4)
            }

            // 目标频道选择
            targetChannelSelector
        }
        .padding(.top, 20)
    }

    // MARK: - Target Channel Selector

    private var targetChannelSelector: some View {
        Button(action: { showChannelPicker = true }) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)

                if let target = targetChannel {
                    Text("发送到: \(target.name)")
                        .font(.caption)
                        .fontWeight(.medium)
                } else if availableChannels.isEmpty {
                    Text("请先订阅频道")
                        .font(.caption)
                } else {
                    Text("选择目标频道")
                        .font(.caption)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(targetChannel != nil ? ApocalypseTheme.textPrimary : ApocalypseTheme.warning)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(8)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showChannelPicker) {
            channelPickerSheet
        }
    }

    private var channelPickerSheet: some View {
        NavigationStack {
            List {
                if availableChannels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 40))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text("暂无可用频道")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("请先在频道中心订阅或创建频道")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(availableChannels) { subscribedChannel in
                        let channel = subscribedChannel.channel
                        let isSelected = targetChannel?.id == channel.id

                        Button(action: {
                            communicationManager.setPTTTargetChannel(channel.id)
                            showChannelPicker = false
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(channel.channelType.color.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: channel.channelType.icon)
                                        .foregroundColor(channel.channelType.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(ApocalypseTheme.textPrimary)
                                    Text(channel.channelType.displayName)
                                        .font(.caption2)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ApocalypseTheme.primary)
                                }
                            }
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ApocalypseTheme.background)
            .navigationTitle("选择目标频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showChannelPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Status Display

    private var statusDisplay: some View {
        VStack(spacing: 16) {
            // Signal animation
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            isPressing ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(60 + i * 40), height: CGFloat(60 + i * 40))
                        .opacity(isPressing ? (1.0 - Double(i) * 0.3) : 0.3)
                        .scaleEffect(isPressing ? 1.1 : 1.0)
                        .animation(
                            isPressing ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.1) : .default,
                            value: isPressing
                        )
                }

                Image(systemName: isPressing ? "waveform" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundColor(isPressing ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            }
            .frame(height: 160)

            // Status text
            Text(isPressing ? "正在发送..." : (canSend ? "按住按钮发送消息" : "当前设备无法发送"))
                .font(.subheadline)
                .foregroundColor(isPressing ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - PTT Button

    private var canSend: Bool {
        (communicationManager.currentDevice?.canSend ?? false) && targetChannel != nil
    }

    private var cannotSendReason: String {
        if !(communicationManager.currentDevice?.canSend ?? false) {
            return "请切换到可发送设备"
        }
        if targetChannel == nil {
            return "请选择目标频道"
        }
        return ""
    }

    private var pttButtonArea: some View {
        VStack(spacing: 16) {
            // Text input (optional)
            HStack {
                TextField("输入消息（可选）", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(8)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !messageText.isEmpty {
                    Button(action: { messageText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            // PTT Button
            ZStack {
                Circle()
                    .fill(
                        isPressing
                        ? (isEmergencyMode ? ApocalypseTheme.danger : ApocalypseTheme.primary)
                        : ApocalypseTheme.cardBackground
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: isPressing ? (isEmergencyMode ? Color.red : Color.orange).opacity(0.5) : Color.clear, radius: 20)

                Image(systemName: isPressing ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isPressing ? .white : ApocalypseTheme.primary)
            }
            .opacity(canSend && !isSending ? 1.0 : 0.5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if canSend && !isSending && !isPressing {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressing = true
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        if isPressing {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressing = false
                            }
                            sendMessage()
                        }
                    }
            )

            Text(canSend ? "按住发送" : cannotSendReason)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Quick Messages

    private var quickMessageBar: some View {
        VStack(spacing: 8) {
            Button(action: { withAnimation { showQuickMessages.toggle() } }) {
                HStack {
                    Text("快捷消息")
                        .font(.caption)
                    Image(systemName: showQuickMessages ? "chevron.down" : "chevron.up")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if showQuickMessages {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickMessages, id: \.self) { msg in
                            Button(action: {
                                messageText = msg
                                sendMessage()
                            }) {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(ApocalypseTheme.cardBackground)
                                    .cornerRadius(16)
                            }
                            .disabled(!canSend || isSending)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Emergency Toggle

    private var emergencyToggle: some View {
        HStack {
            Toggle(isOn: $isEmergencyMode) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(isEmergencyMode ? .red : ApocalypseTheme.textSecondary)
                    Text("紧急模式")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .red))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Sent Feedback Overlay

    private func sentFeedbackOverlay(_ message: String) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text("已发送")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let channelName = sentToChannel {
                    Text("发送到: \(channelName)")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                Text(message)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)

                // 查看消息按钮
                Button(action: {
                    // 找到目标频道并导航
                    if let targetId = targetChannel?.id,
                       let subscribedChannel = communicationManager.subscribedChannels.first(where: { $0.channel.id == targetId }) {
                        navigateToChannel = subscribedChannel.channel
                    }
                    showSentFeedback = false
                }) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("查看消息")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)

            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .transition(.opacity)
    }

    // MARK: - Methods

    private func sendMessage() {
        let content = messageText.isEmpty ? "位置信号" : messageText

        // 记录目标频道名称
        let channelName = targetChannel?.name

        isSending = true

        Task {
            do {
                _ = try await communicationManager.sendPTTMessage(
                    content: content,
                    isEmergency: isEmergencyMode
                )

                // Show feedback
                await MainActor.run {
                    sentMessage = content
                    sentToChannel = channelName
                    withAnimation {
                        showSentFeedback = true
                    }
                    messageText = ""

                    // Hide feedback after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showSentFeedback = false
                            sentMessage = nil
                            sentToChannel = nil
                        }
                    }
                }

                // Success haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

            } catch {
                print("PTT发送失败: \(error)")
                // Error haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }

            isSending = false
        }
    }
}

#Preview {
    PTTCallView()
        .environmentObject(AuthManager.shared)
}
