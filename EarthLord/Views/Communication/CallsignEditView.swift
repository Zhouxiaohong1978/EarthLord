//
//  CallsignEditView.swift
//  EarthLord
//
//  呼号编辑界面
//

import SwiftUI
import Auth

struct CallsignEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var callsign = ""
    @State private var isLoading = false
    @State private var isChecking = false
    @State private var isAvailable: Bool? = nil  // nil=未检测, true=可用, false=已占用
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var checkTask: Task<Void, Never>? = nil

    private var isValid: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    private var isUnchanged: Bool {
        callsign.lowercased() == (communicationManager.userCallsign ?? "").lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 当前呼号展示
                        VStack(spacing: 12) {
                            Text("当前呼号")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(communicationManager.userCallsign ?? String(localized: "未设置"))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(ApocalypseTheme.primary)

                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption)
                                Text("呼号是您在频道中的身份标识")
                                    .font(.caption)
                            }
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        // 编辑区
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("自定义呼号")
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                Spacer()
                                Text("\(callsign.count)/20")
                                    .font(.caption)
                                    .foregroundColor(
                                        callsign.count > 20 ? ApocalypseTheme.danger :
                                        isValid ? ApocalypseTheme.success :
                                        ApocalypseTheme.textSecondary
                                    )
                            }

                            HStack {
                                TextField("例如：LZ-Scout-001", text: $callsign)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .onChange(of: callsign) { newValue in
                                        if newValue.count > 20 {
                                            callsign = String(newValue.prefix(20))
                                        }
                                        scheduleAvailabilityCheck()
                                    }

                                // 可用性状态图标
                                if isChecking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                                        .scaleEffect(0.7)
                                } else if let available = isAvailable {
                                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(available ? ApocalypseTheme.success : ApocalypseTheme.danger)
                                }
                            }
                            .padding(12)
                            .background(ApocalypseTheme.background)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        callsign.isEmpty ? Color.clear :
                                        !isValid ? ApocalypseTheme.danger.opacity(0.5) :
                                        isAvailable == false ? ApocalypseTheme.danger.opacity(0.5) :
                                        isAvailable == true ? ApocalypseTheme.success.opacity(0.5) :
                                        Color.clear,
                                        lineWidth: 1
                                    )
                            )

                            if !callsign.isEmpty && !isValid {
                                Text("呼号需要 2-20 个字符")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.danger)
                            } else if isAvailable == false {
                                Text("该呼号已被使用，请换一个")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.danger)
                            } else if isAvailable == true && !isUnchanged {
                                Text("呼号可用")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.success)
                            }
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        // 说明
                        Text("呼号会显示在你发出的每条消息旁边，方便其他玩家识别你")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        // 保存按钮
                        Button(action: saveCallsign) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("保存呼号")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !isValid || isAvailable == false || isChecking)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("编辑呼号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                callsign = communicationManager.userCallsign ?? ""
            }
        }
    }

    // 防抖：输入停止 0.6 秒后检测
    private func scheduleAvailabilityCheck() {
        isAvailable = nil
        checkTask?.cancel()
        guard isValid else { return }
        if isUnchanged {
            isAvailable = true
            return
        }
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            isChecking = true
            let available = await communicationManager.isCallsignAvailable(callsign.trimmingCharacters(in: .whitespacesAndNewlines))
            isChecking = false
            isAvailable = available
        }
    }

    private func saveCallsign() {
        guard let userId = authManager.currentUser?.id else { return }
        let trimmed = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        Task {
            do {
                try await communicationManager.updateCallsign(userId: userId, newCallsign: trimmed)
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    CallsignEditView()
        .environmentObject(AuthManager.shared)
}
