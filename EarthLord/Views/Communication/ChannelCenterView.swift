//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心 - 显示我的频道和发现频道
//

import SwiftUI
import Auth

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var searchText = ""
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // Tab 切换
            tabSelector

            // 内容区域
            TabView(selection: $selectedTab) {
                myChannelsView
                    .tag(0)

                discoverChannelsView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("频道中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", count: communicationManager.subscribedChannels.count, tag: 0)
            tabButton(title: "发现频道", count: nil, tag: 1)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    private func tabButton(title: String, count: Int?, tag: Int) -> some View {
        Button(action: { withAnimation { selectedTab = tag } }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tag ? .semibold : .regular)

                    if let count = count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.primary.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == tag ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == tag ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - My Channels View

    private var myChannelsView: some View {
        ScrollView {
            if communicationManager.isLoading && communicationManager.subscribedChannels.isEmpty {
                loadingView
            } else if communicationManager.subscribedChannels.isEmpty {
                emptyMyChannelsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                        NavigationLink(destination: ChannelChatView(channel: subscribedChannel.channel).environmentObject(authManager)) {
                            ChannelRowView(channel: subscribedChannel.channel, isSubscribed: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(action: { selectedChannel = subscribedChannel.channel }) {
                                Label("频道详情", systemImage: "info.circle")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await loadData()
        }
    }

    private var emptyMyChannelsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无订阅频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("创建新频道或去发现页面订阅")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button(action: { showCreateSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("创建频道")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Discover Channels View

    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            ScrollView {
                if communicationManager.isLoading && communicationManager.channels.isEmpty {
                    loadingView
                } else if filteredChannels.isEmpty {
                    emptyDiscoverView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                    .padding()
                }
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索频道...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emptyDiscoverView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(searchText.isEmpty ? "暂无公共频道" : "未找到匹配频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(searchText.isEmpty ? "成为第一个创建频道的人" : "尝试其他关键词")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Methods

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }

        do {
            _ = try await communicationManager.loadPublicChannels()
            _ = try await communicationManager.loadSubscribedChannels(userId: userId)
        } catch {
            print("加载频道数据失败: \(error)")
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channel.channelType.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: channel.channelType.icon)
                    .font(.title3)
                    .foregroundColor(channel.channelType.color)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }

                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    Label("\(channel.memberCount)", systemImage: "person.2.fill")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(channel.channelType.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(channel.channelType.color.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
}
