//
//  PTTCallView.swift
//  EarthLord
//
//  PTT通话界面 - Day 36 实现
//  类似对讲机的按住说话界面
//

import SwiftUI
import AVFoundation

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

    // MARK: - 录音状态
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordingFileURL: URL?
    @State private var isCancelled = false      // 上滑取消标志
    @State private var dragOffset: CGFloat = 0  // 按钮拖动偏移

    // MARK: - 幸存者呼叫状态
    @State private var isSendingSurvivorCall = false
    @State private var showSurvivorCallSent = false
    @State private var survivorCallPulse = false
    @State private var showSurvivorCallConfirm = false
    @State private var survivorCallError: String?

    // Quick message templates
    private var quickMessages: [String] {
        [
            String(localized: "收到，明白"),
            String(localized: "需要支援"),
            String(localized: "发现资源"),
            String(localized: "位置安全"),
            String(localized: "正在撤离"),
            String(localized: "保持静默")
        ]
    }

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
        ScrollView {
            VStack(spacing: 0) {
                // Header with device info
                headerView

                // Status display
                statusDisplay
                    .padding(.vertical, 24)

                // PTT button area
                pttButtonArea

                // Quick messages
                quickMessageBar

                // Emergency toggle
                emergencyToggle
                    .padding(.bottom, 8)

                // 幸存者呼叫
                survivorCallButton
                    .padding(.bottom, 16)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(ApocalypseTheme.background)
        .alert("发送失败", isPresented: .constant(survivorCallError != nil)) {
            Button("确定") { survivorCallError = nil }
        } message: {
            Text(survivorCallError ?? "")
        }
        .alert("发送求救信号", isPresented: $showSurvivorCallConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认发送") { sendSurvivorCall() }
        } message: {
            if let name = targetChannel?.name {
                Text("将向频道「\(name)」发送【求生信号】，频道内所有成员都会收到。")
            } else {
                Text("请先选择目标频道")
            }
        }
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
            Text(String(localized: "PTT 通话"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if let device = communicationManager.currentDevice {
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.iconName)
                    Text(device.deviceType.displayName)
                    Text("·")
                    Text(String(format: String(localized: "覆盖 %@"), device.deviceType.rangeText))
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // Callsign
            if let callsign = communicationManager.userCallsign {
                Text(String(format: String(localized: "呼号: %@"), callsign))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.top, 4)
            }

            // 目标频道选择
            targetChannelSelector
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Target Channel Selector

    private var targetChannelSelector: some View {
        Button(action: { showChannelPicker = true }) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)

                if let target = targetChannel {
                    Text(String(format: String(localized: "发送到: %@"), target.name))
                        .font(.caption)
                        .fontWeight(.medium)
                } else if availableChannels.isEmpty {
                    Text(String(localized: "请先订阅频道"))
                        .font(.caption)
                } else {
                    Text(String(localized: "选择目标频道"))
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
                        Text(String(localized: "暂无可用频道"))
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(String(localized: "请先在频道中心订阅或创建频道"))
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
            .navigationTitle(String(localized: "选择目标频道"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { showChannelPicker = false }
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
            Text(isPressing ? String(localized: "正在发送...") : (canSend ? String(localized: "按住按钮发送消息") : String(localized: "当前设备无法发送")))
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
            return String(localized: "请切换到可发送设备")
        }
        if targetChannel == nil {
            return String(localized: "请选择目标频道")
        }
        return ""
    }

    private var pttButtonArea: some View {
        VStack(spacing: 16) {
            // 文字输入框（可选）
            HStack {
                TextField(String(localized: "输入文字消息（可选）"), text: $messageText)
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

            // 录音时长 / 取消提示
            if isRecording {
                HStack(spacing: 8) {
                    if isCancelled {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.danger)
                        Text("松开取消")
                            .foregroundColor(ApocalypseTheme.danger)
                    } else {
                        Circle()
                            .fill(ApocalypseTheme.danger)
                            .frame(width: 8, height: 8)
                            .opacity(recordingDuration.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                        Text(String(format: "%.0f\"", recordingDuration))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .monospacedDigit()
                        Text("Slide up to cancel")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .transition(.opacity)
            }

            // PTT 按钮（按住录音 / 文字有内容时点击发送文字）
            ZStack {
                // 外圈脉冲（录音中）
                if isRecording && !isCancelled {
                    Circle()
                        .stroke(ApocalypseTheme.danger.opacity(0.4), lineWidth: 2)
                        .frame(width: 130, height: 130)
                        .scaleEffect(isRecording ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isRecording)
                }

                Circle()
                    .fill(
                        isCancelled ? ApocalypseTheme.danger.opacity(0.3) :
                        isRecording ? ApocalypseTheme.danger :
                        isEmergencyMode ? ApocalypseTheme.danger.opacity(0.8) :
                        ApocalypseTheme.cardBackground
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: isRecording ? Color.red.opacity(0.5) : Color.clear, radius: 20)
                    .offset(y: dragOffset)

                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isRecording ? .white : ApocalypseTheme.primary)
                    .offset(y: dragOffset)
            }
            .opacity(canSend && !isSending ? 1.0 : 0.5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard canSend && !isSending else { return }
                        if !isRecording {
                            startRecording()
                        }
                        // 上滑距离 > 60pt 进入取消模式
                        dragOffset = min(0, value.translation.height)
                        let newCancelled = value.translation.height < -60
                        if newCancelled != isCancelled {
                            isCancelled = newCancelled
                            let gen = UIImpactFeedbackGenerator(style: .rigid)
                            gen.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        guard isRecording else { return }
                        dragOffset = 0
                        if isCancelled {
                            cancelRecording()
                        } else {
                            stopAndSendRecording()
                        }
                    }
            )

            // 提示文字
            if !isRecording {
                VStack(spacing: 4) {
                    Text(canSend ? "Hold to record · Slide up to cancel" : cannotSendReason)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    if canSend && !messageText.isEmpty {
                        Button("Send text message") { sendMessage() }
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    // MARK: - Quick Messages

    private var quickMessageBar: some View {
        VStack(spacing: 8) {
            Button(action: { withAnimation { showQuickMessages.toggle() } }) {
                HStack {
                    Text(String(localized: "快捷消息"))
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
                    Text(String(localized: "紧急模式"))
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

    // MARK: - 幸存者呼叫

    private var survivorCallButton: some View {
        VStack(spacing: 8) {
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.horizontal, 20)

            Button(action: { showSurvivorCallConfirm = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        // 脉冲光环
                        if survivorCallPulse {
                            Circle()
                                .stroke(ApocalypseTheme.info.opacity(0.4), lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .scaleEffect(survivorCallPulse ? 1.4 : 1.0)
                                .opacity(survivorCallPulse ? 0 : 1)
                                .animation(
                                    .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                    value: survivorCallPulse
                                )
                        }

                        Circle()
                            .fill(ApocalypseTheme.info.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "person.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.info)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("幸存者呼叫")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("向频道广播求生信号")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    if isSendingSurvivorCall {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if showSurvivorCallSent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            .disabled(isSendingSurvivorCall || isSending || targetChannel == nil)
            .opacity(!isSendingSurvivorCall ? 1.0 : 0.5)
        }
    }

    private func sendSurvivorCall() {
        guard let channelId = targetChannel?.id else { return }
        let channelName = targetChannel?.name

        isSendingSurvivorCall = true
        survivorCallPulse = true

        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        Task {
            do {
                try await communicationManager.sendChannelMessage(
                    channelId: channelId,
                    content: "【求生信号】有人吗？",
                    latitude: latitude,
                    longitude: longitude
                )

                await MainActor.run {
                    isSendingSurvivorCall = false
                    showSurvivorCallSent = true
                    sentMessage = "【求生信号】有人吗？"
                    sentToChannel = channelName
                    withAnimation { showSentFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            showSentFeedback = false
                            showSurvivorCallSent = false
                            survivorCallPulse = false
                        }
                    }
                }

                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)

            } catch {
                await MainActor.run {
                    isSendingSurvivorCall = false
                    survivorCallPulse = false
                    survivorCallError = error.localizedDescription
                    print("❌ [幸存者呼叫] 发送失败: \(error)")
                }
            }
        }
    }

    // MARK: - Sent Feedback Overlay

    private func sentFeedbackOverlay(_ message: String) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text(String(localized: "已发送"))
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let channelName = sentToChannel {
                    Text(String(format: String(localized: "发送到: %@"), channelName))
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
                        Text(String(localized: "查看消息"))
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

    // MARK: - Recording Methods

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? session.setActive(true)

        let fileName = UUID().uuidString + ".m4a"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        recordingFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record(forDuration: 30)

        isRecording = true
        isCancelled = false
        recordingDuration = 0

        // 计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                recordingDuration += 0.1
                if recordingDuration >= 30 {
                    stopAndSendRecording()
                }
            }
        }

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        withAnimation { isPressing = true }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        withAnimation {
            isRecording = false
            isPressing = false
            dragOffset = 0
        }
    }

    private func cancelRecording() {
        stopRecording()
        isCancelled = false
        if let url = recordingFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingFileURL = nil

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }

    private func stopAndSendRecording() {
        guard let fileURL = recordingFileURL, recordingDuration > 0.5 else {
            cancelRecording()
            return
        }
        stopRecording()

        let channelName = targetChannel?.name
        isSending = true

        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        Task {
            do {
                guard let channelId = targetChannel?.id else { return }
                try await communicationManager.sendVoiceMessage(
                    channelId: channelId,
                    fileURL: fileURL,
                    latitude: latitude,
                    longitude: longitude
                )
                try? FileManager.default.removeItem(at: fileURL)
                recordingFileURL = nil

                await MainActor.run {
                    isSending = false
                    sentMessage = "🎤 语音消息"
                    sentToChannel = channelName
                    withAnimation { showSentFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSentFeedback = false }
                    }
                }

                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)

            } catch {
                await MainActor.run { isSending = false }
                print("语音消息发送失败: \(error)")
            }
        }
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
