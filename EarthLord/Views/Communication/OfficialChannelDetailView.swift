//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页 - 顶部分类筛选 + 消息列表
//

import SwiftUI
import Auth

// MARK: - 官方频道主页

struct OfficialChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messages: [ChannelMessage] = []
    @State private var isLoading = true
    @State private var selectedCategory: MessageCategory? = nil  // nil = 全部

    /// 当前筛选后的消息（全部按时间倒序，分类内也倒序）
    private var filteredMessages: [ChannelMessage] {
        if let cat = selectedCategory {
            return messages.filter { $0.category == cat }
        }
        return messages
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分类标签栏（固定在顶部）
            categoryTabBar

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 消息列表 / 任务发布特殊页
            if selectedCategory == .mission {
                DailyTaskView()
            } else if isLoading {
                loadingView
            } else if filteredMessages.isEmpty {
                emptyView
            } else {
                messageList
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
        .refreshable {
            await loadMessages()
        }
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await communicationManager.markChannelAsRead(
                        userId: userId,
                        channelId: CommunicationManager.officialChannelId
                    )
                }
            }
        }
    }

    // MARK: - 分类标签栏

    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                categoryTab(
                    label: LanguageManager.shared.localizedString(for: "全部"),
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil,
                    count: nil
                ) {
                    selectedCategory = nil
                }

                // 各分类（mission 已排第一）
                ForEach(MessageCategory.allCases, id: \.rawValue) { cat in
                    let count = messages.filter { $0.category == cat }.count
                    categoryTab(
                        label: cat.displayName,
                        icon: cat.iconName,
                        color: cat.color,
                        isSelected: selectedCategory == cat,
                        count: count > 0 ? count : nil
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    private func categoryTab(
        label: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        count: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                if let n = count {
                    Text("\(n)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    OfficialMessageCard(message: message, isAdmin: authManager.isAdmin) {
                        Task { await deleteMessage(message) }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            let cat = selectedCategory
            Image(systemName: cat?.iconName ?? "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text(cat == nil
                 ? LanguageManager.shared.localizedString(for: "暂无消息")
                 : String(format: LanguageManager.shared.localizedString(for: "暂无%@"), cat!.displayName))
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(LanguageManager.shared.localizedString(for: "请稍后再来查看"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Text(LanguageManager.shared.localizedString(for: "加载中..."))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Methods

    private func loadMessages() async {
        isLoading = true
        do {
            messages = try await communicationManager.loadOfficialMessages()
        } catch {
            print("加载官方消息失败: \(error)")
        }
        isLoading = false
    }

    private func deleteMessage(_ message: ChannelMessage) async {
        do {
            try await communicationManager.deleteOfficialMessage(messageId: message.messageId)
            messages.removeAll { $0.messageId == message.messageId }
        } catch {
            print("删除消息失败: \(error)")
        }
    }
}

// MARK: - Official Message Card

struct OfficialMessageCard: View {
    let message: ChannelMessage
    var isAdmin: Bool = false
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let category = message.category {
                    HStack(spacing: 4) {
                        Image(systemName: category.iconName)
                            .font(.caption)
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color)
                    .cornerRadius(4)
                }

                Spacer()

                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if isAdmin {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                    .padding(.leading, 8)
                    .confirmationDialog("删除这条消息？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("删除", role: .destructive) { onDelete?() }
                        Button("取消", role: .cancel) {}
                    }
                }
            }

            // Content
            Text(message.localizedContent)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(nil)

            // Footer
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.caption2)
                Text(message.senderCallsign == "末日广播站" || message.senderCallsign == nil ? LanguageManager.shared.localizedString(for: "末日广播站") : message.senderCallsign!)
                    .font(.caption2)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.category?.color.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        OfficialChannelDetailView()
            .environmentObject(AuthManager.shared)
    }
}
