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

    // Quick message templates
    private let quickMessages = [
        "收到，明白",
        "需要支援",
        "发现资源",
        "位置安全",
        "正在撤离",
        "保持静默"
    ]

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
        }
        .padding(.top, 20)
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
        communicationManager.currentDevice?.canSend ?? false
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
                    .shadow(color: isPressing ? (isEmergencyMode ? .red : .orange).opacity(0.5) : .clear, radius: 20)

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

            Text(canSend ? "按住发送" : "请切换到可发送设备")
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

            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text("已发送")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(1)
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
                    withAnimation {
                        showSentFeedback = true
                    }
                    messageText = ""

                    // Hide feedback after 1.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showSentFeedback = false
                            sentMessage = nil
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
