//
//  CallsignEditView.swift
//  EarthLord
//
//  呼号编辑界面 - Day 36 实现
//

import SwiftUI

struct CallsignEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Callsign format components
    @State private var region = "BJ"
    @State private var rank = "Alpha"
    @State private var number = "001"

    let regions = ["BJ", "SH", "GZ", "SZ", "CD", "HZ", "NJ", "WH", "XA", "CQ"]
    let ranks = ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"]

    var composedCallsign: String {
        let paddedNumber = number.padding(toLength: 3, withPad: "0", startingAt: 0)
        return "\(region)-\(rank)-\(paddedNumber)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Current callsign display
                        currentCallsignCard

                        // Editor
                        editorCard

                        // Info
                        infoText

                        // Save button
                        saveButton
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
                parseCurrentCallsign()
            }
        }
    }

    // MARK: - Current Callsign Card

    private var currentCallsignCard: some View {
        VStack(spacing: 12) {
            Text("当前呼号")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(communicationManager.userCallsign ?? "未设置")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.primary)

            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                Text("呼号是您在通讯中的身份标识")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Editor Card

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑呼号")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Region picker
            HStack {
                Text("地区")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                Picker("地区", selection: $region) {
                    ForEach(regions, id: \.self) { r in
                        Text(regionName(r)).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .tint(ApocalypseTheme.primary)

                Spacer()
            }

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // Rank picker
            HStack {
                Text("等级")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                Picker("等级", selection: $rank) {
                    ForEach(ranks, id: \.self) { r in
                        Text(r).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .tint(ApocalypseTheme.primary)

                Spacer()
            }

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // Number input
            HStack {
                Text("编号")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                TextField("001", text: $number)
                    .keyboardType(.numberPad)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(10)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(8)
                    .frame(width: 80)
                    .onChange(of: number) { _, newValue in
                        // Limit to 3 digits
                        if newValue.count > 3 {
                            number = String(newValue.prefix(3))
                        }
                        // Only allow digits
                        number = newValue.filter { $0.isNumber }
                    }

                Text("(001-999)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)

                Spacer()
            }

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // Preview
            HStack {
                Text("预览")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                Text(composedCallsign)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)

                Spacer()
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Info Text

    private var infoText: some View {
        VStack(spacing: 4) {
            Text("呼号格式：地区-等级-编号")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("例如：BJ-Alpha-001 表示北京地区Alpha级别001号")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Save Button

    private var saveButton: some View {
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
            .background(ApocalypseTheme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading || number.isEmpty)
        .opacity(isLoading || number.isEmpty ? 0.6 : 1.0)
    }

    // MARK: - Helper Methods

    private func regionName(_ code: String) -> String {
        let names: [String: String] = [
            "BJ": "北京 BJ",
            "SH": "上海 SH",
            "GZ": "广州 GZ",
            "SZ": "深圳 SZ",
            "CD": "成都 CD",
            "HZ": "杭州 HZ",
            "NJ": "南京 NJ",
            "WH": "武汉 WH",
            "XA": "西安 XA",
            "CQ": "重庆 CQ"
        ]
        return names[code] ?? code
    }

    private func parseCurrentCallsign() {
        guard let current = communicationManager.userCallsign else { return }

        let parts = current.split(separator: "-")
        if parts.count == 3 {
            region = String(parts[0])
            rank = String(parts[1])
            number = String(parts[2])
        }
    }

    private func saveCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true

        Task {
            do {
                try await communicationManager.updateCallsign(userId: userId, newCallsign: composedCallsign)
                await MainActor.run {
                    // Success haptic
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
