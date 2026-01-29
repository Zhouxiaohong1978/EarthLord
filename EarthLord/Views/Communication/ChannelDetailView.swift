//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情视图
//

import SwiftUI
import Auth

struct ChannelDetailView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头部
                    channelHeader

                    // 订阅状态
                    subscriptionStatus

                    // 频道信息卡片
                    channelInfoCard

                    // 错误提示
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // 操作按钮
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("确定要删除频道「\(channel.name)」吗？此操作不可撤销。")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channel.channelType.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.icon)
                    .font(.system(size: 36))
                    .foregroundColor(channel.channelType.color)
            }

            // 频道名称
            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)

            // 频道码
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.caption)
                Text(channel.channelCode)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Button(action: copyChannelCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
        .padding(.top, 8)
    }

    // MARK: - Subscription Status

    private var subscriptionStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: isSubscribed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSubscribed ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

            Text(isSubscribed ? "已订阅" : "未订阅")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSubscribed ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

            if isCreator {
                Text("· 创建者")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSubscribed ? ApocalypseTheme.success.opacity(0.1) : ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Channel Info Card

    private var channelInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("频道信息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                infoRow(icon: "dot.radiowaves.left.and.right", title: "类型", value: channel.channelType.displayName, color: channel.channelType.color)
                infoRow(icon: "person.2.fill", title: "成员", value: "\(channel.memberCount) 人")
                infoRow(icon: "calendar", title: "创建时间", value: formatDate(channel.createdAt))

                if let description = channel.description, !description.isEmpty {
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.3))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("描述")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    private func infoRow(icon: String, title: String, value: String, color: Color = ApocalypseTheme.textPrimary) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)

            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.danger)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 订阅/取消订阅按钮
            if !isCreator {
                subscribeButton
            }

            // 删除按钮（仅创建者可见）
            if isCreator {
                deleteButton
            }
        }
    }

    private var subscribeButton: some View {
        Button(action: toggleSubscription) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.textPrimary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isSubscribed ? "bell.slash.fill" : "bell.fill")
                }
                Text(isSubscribed ? "取消订阅" : "订阅频道")
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSubscribed ? ApocalypseTheme.textSecondary.opacity(0.3) : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
    }

    private var deleteButton: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack {
                Image(systemName: "trash.fill")
                Text("删除频道")
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.danger.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
            )
        }
        .disabled(isProcessing)
    }

    // MARK: - Methods

    private func copyChannelCode() {
        UIPasteboard.general.string = channel.channelCode
    }

    private func toggleSubscription() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                if isSubscribed {
                    try await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
                } else {
                    try await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
                }

                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func deleteChannel() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                try await communicationManager.deleteChannel(channelId: channel.id)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    // 创建预览用的模拟数据
    let previewChannel = try! JSONDecoder().decode(
        CommunicationChannel.self,
        from: """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "creator_id": "550e8400-e29b-41d4-a716-446655440001",
            "channel_type": "public",
            "channel_code": "PUB-ABC123",
            "name": "幸存者联盟",
            "description": "这是一个公共频道，欢迎所有幸存者加入讨论。",
            "is_active": true,
            "member_count": 42,
            "created_at": "2024-01-15T08:00:00Z",
            "updated_at": "2024-01-15T08:00:00Z"
        }
        """.data(using: .utf8)!
    )

    ChannelDetailView(channel: previewChannel)
        .environmentObject(AuthManager.shared)
}
