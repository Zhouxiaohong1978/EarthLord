//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页 - Day 36 实现
//  支持消息分类过滤
//

import SwiftUI
import Auth

struct OfficialChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = true
    @State private var messages: [ChannelMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            // Category filter tabs
            categoryTabs

            // Messages list
            if isLoading {
                loadingView
            } else if filteredMessages.isEmpty {
                emptyView
            } else {
                messageListView
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("末日广播站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("末日广播站")
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
            // 标记已读
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

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All category
                categoryButton(nil, title: "全部")

                // Specific categories
                ForEach(MessageCategory.allCases, id: \.rawValue) { category in
                    categoryButton(category, title: category.displayName)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    private func categoryButton(_ category: MessageCategory?, title: String) -> some View {
        let isSelected = selectedCategory == category

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 4) {
                if let cat = category {
                    Image(systemName: cat.iconName)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? (category?.color ?? ApocalypseTheme.primary) : ApocalypseTheme.background)
            .cornerRadius(16)
        }
    }

    // MARK: - Filtered Messages

    private var filteredMessages: [ChannelMessage] {
        guard let category = selectedCategory else {
            return messages
        }
        return messages.filter { $0.category == category }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    OfficialMessageCard(message: message)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Loading & Empty

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: selectedCategory?.iconName ?? "megaphone")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(selectedCategory == nil ? "暂无广播" : "暂无\(selectedCategory!.displayName)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请稍后再来查看")
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
}

// MARK: - Official Message Card

struct OfficialMessageCard: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category badge
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
                Text(message.senderCallsign ?? "末日广播站")
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
