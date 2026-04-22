//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心 - 搜索入口 + 附近频道列表
//

import SwiftUI
import Auth

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @ObservedObject private var locationManager = LocationManager.shared

    @State private var showSearchSheet = false
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            ScrollView {
                VStack(spacing: 16) {
                    // 搜索频道入口
                    searchEntry

                    // 附近频道
                    nearbySection
                }
                .padding(16)
            }
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showSearchSheet) {
            ChannelSearchView()
                .environmentObject(authManager)
        }
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
        .refreshable {
            await loadData()
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text(String(localized: "频道中心"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索入口

    private var deviceRangeLabel: String {
        guard let device = communicationManager.currentDevice else { return "—" }
        let range = device.currentRange
        if device.deviceType == .radio { return String(localized: "仅收听") }
        if range >= 100 { return "100km+" }
        return "\(Int(range)) km"
    }

    private var searchEntry: some View {
        Button(action: { showSearchSheet = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "搜索频道"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(String(localized: "按名称或频道号查找"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 11))
                    Text(deviceRangeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.primary.opacity(0.12))
                .cornerRadius(8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 附近频道

    /// 当前设备范围（km），nil = 无限制
    private var deviceRangeKm: Double? {
        guard let device = communicationManager.currentDevice else { return nil }
        let r = device.currentRange
        return r == Double.infinity ? nil : r
    }

    /// 附近频道（含已订阅），按设备范围过滤，自己的频道和已订阅优先
    private var allNearbyChannels: [CommunicationChannel] {
        let myId = authManager.currentUser?.id
        let filtered = communicationManager.channels.filter { ch in
            guard !communicationManager.isOfficialChannel(ch.id) else { return false }
            guard let maxKm = deviceRangeKm else { return true }
            guard let playerLoc = locationManager.userLocation else { return true }
            guard let dist = ch.distance(from: playerLoc) else { return true }
            return dist <= maxKm
        }
        return filtered.sorted { a, b in
            let aOwn = a.creatorId == myId
            let bOwn = b.creatorId == myId
            let aSub = communicationManager.isSubscribed(channelId: a.id)
            let bSub = communicationManager.isSubscribed(channelId: b.id)
            // 自己的频道 > 已订阅 > 其他
            let aScore = aOwn ? 2 : (aSub ? 1 : 0)
            let bScore = bOwn ? 2 : (bSub ? 1 : 0)
            return aScore > bScore
        }
    }

    private var nearbySection: some View {
        VStack(spacing: 10) {
            // 区块标题 + 数量
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: deviceRangeKm == nil ? "globe" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(deviceRangeKm == nil ? String(localized: "全部频道") : String(localized: "附近频道"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                Text("\(allNearbyChannels.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ApocalypseTheme.primary.opacity(0.25))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            if communicationManager.isLoading && allNearbyChannels.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .padding(.vertical, 24)
            } else if allNearbyChannels.isEmpty {
                emptyNearbyView
            } else {
                ForEach(allNearbyChannels) { channel in
                    let isOfficial = communicationManager.isOfficialChannel(channel.id)
                    let isSubscribed = communicationManager.isSubscribed(channelId: channel.id)

                    if isOfficial {
                        NavigationLink(destination: OfficialChannelDetailView().environmentObject(authManager)) {
                            ChannelRowView(channel: channel, isSubscribed: true, isOfficial: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        ChannelRowView(channel: channel, isSubscribed: isSubscribed, isOfficial: false)
                            .onTapGesture {
                                selectedChannel = channel
                            }
                    }
                }
            }
        }
    }

    private var emptyNearbyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text(String(localized: "附近暂无频道"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text(String(localized: "升级设备可扩大搜索范围"))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - 加载数据

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

// MARK: - 频道搜索视图

struct ChannelSearchView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedChannel: CommunicationChannel?

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty { return communicationManager.channels }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        TextField(String(localized: "搜索频道名称或频道号..."), text: $searchText)
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
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if filteredChannels.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
                                    Text(searchText.isEmpty ? String(localized: "输入关键词开始搜索") : String(localized: "未找到匹配频道"))
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                            } else {
                                ForEach(filteredChannels) { channel in
                                    let isOfficial = communicationManager.isOfficialChannel(channel.id)
                                    let isSubscribed = communicationManager.isSubscribed(channelId: channel.id)
                                    ChannelRowView(channel: channel, isSubscribed: isSubscribed, isOfficial: isOfficial)
                                        .onTapGesture { selectedChannel = channel }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle(String(localized: "搜索频道"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "关闭")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool
    var isOfficial: Bool = false

    @StateObject private var communicationManager = CommunicationManager.shared

    private var isFavorited: Bool {
        communicationManager.isFavorited(channelId: channel.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOfficial ? ApocalypseTheme.primary.opacity(0.2) : channel.channelType.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: isOfficial ? "megaphone.fill" : channel.channelType.icon)
                    .font(.title3)
                    .foregroundColor(isOfficial ? ApocalypseTheme.primary : channel.channelType.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(isOfficial ? String(localized: "末日广播站") : channel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                    } else if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }

                Text(isOfficial ? String(localized: "全球覆盖 · 官方公告") : channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    if !isOfficial {
                        Label("\(channel.memberCount)", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    Text(isOfficial ? String(localized: "官方频道") : channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(isOfficial ? ApocalypseTheme.primary : channel.channelType.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isOfficial ? ApocalypseTheme.primary : channel.channelType.color).opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 收藏按钮（官方频道不显示）
            if !isOfficial {
                Button {
                    communicationManager.toggleFavorite(channelId: channel.id)
                } label: {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorited ? .yellow : ApocalypseTheme.textMuted)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
            }

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
    NavigationStack {
        ChannelCenterView()
            .environmentObject(AuthManager.shared)
    }
}
