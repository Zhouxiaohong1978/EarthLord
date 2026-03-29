//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页 - 四分类入口 + 分类消息页
//

import SwiftUI
import Auth

// MARK: - 官方频道主页（四分类入口）

struct OfficialChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messages: [ChannelMessage] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 频道头部
                headerBanner

                // 四个分类入口
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MessageCategory.allCases, id: \.rawValue) { category in
                        NavigationLink {
                            OfficialCategoryView(
                                category: category,
                                messages: messages.filter { $0.category == category }
                            )
                            .environmentObject(authManager)
                        } label: {
                            CategoryEntryCard(
                                category: category,
                                count: messages.filter { $0.category == category }.count,
                                latestMessage: messages.filter { $0.category == category }.first
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(String(localized: "末日广播站"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(String(localized: "末日广播站"))
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
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

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(String(localized: "末日广播站"))
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
                Text(isLoading
                     ? String(localized: "加载中...")
                     : String(format: String(localized: "共 %d 条消息"), messages.count))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
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
}

// MARK: - 分类入口卡片

struct CategoryEntryCard: View {
    let category: MessageCategory
    let count: Int
    let latestMessage: ChannelMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 图标 + 消息数角标
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(category.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(category.color)
                }

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(category.color)
                        .clipShape(Capsule())
                }
            }

            // 分类名称
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 最新消息预览
            if let msg = latestMessage {
                Text(msg.content)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                Text(String(localized: "暂无内容"))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 分类消息列表页

struct OfficialCategoryView: View {
    let category: MessageCategory
    let messages: [ChannelMessage]

    var body: some View {
        Group {
            if category == .mission {
                // 任务发布：显示每日任务（不走消息列表）
                DailyTaskView()
            } else if messages.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            OfficialMessageCard(message: message)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: category.iconName)
                        .font(.subheadline)
                        .foregroundColor(category.color)
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: category.iconName)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(String(format: String(localized: "暂无%@"), category.displayName))
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(String(localized: "请稍后再来查看"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Official Message Card

struct OfficialMessageCard: View {
    let message: ChannelMessage

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
            }

            // Content
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(nil)

            // Footer
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.caption2)
                Text(message.senderCallsign ?? String(localized: "末日广播站"))
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
