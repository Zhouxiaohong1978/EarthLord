//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//  Redesigned: 头像居中 + 2×2操作按钮 + 子Tab统计
//

import SwiftUI
import Supabase
import PhotosUI

struct ProfileTabView: View {

    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var dailyRewardManager = DailyRewardManager.shared
    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var explorationStatsManager = ExplorationStatsManager.shared

    @State private var hasPreloaded = false
    @State private var myTerritories: [Territory] = []
    @State private var showEditProfile = false
    @State private var selectedTab: ProfileSubTab = .stats
    @State private var statsTimeFilter: StatsTimeFilter = .week
    @State private var localAvatar: UIImage? = nil

    enum StatsTimeFilter: String, CaseIterable {
        case today = "今日"
        case week  = "本周"
        case month = "本月"
        case all   = "全部"

        var startDate: Date? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .today: return cal.startOfDay(for: now)
            case .week:  return cal.dateInterval(of: .weekOfYear, for: now)?.start
            case .month: return cal.dateInterval(of: .month, for: now)?.start
            case .all:   return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部：头像 + 用户名 + 身份
                        headerSection
                            .padding(.top, 16)

                        // 数据统计行
                        statsInlineRow
                            .padding(.top, 20)
                            .padding(.horizontal, 20)

                        // 操作按钮 2×2
                        actionButtons
                            .padding(.top, 18)
                            .padding(.horizontal, 16)

                        // 子 Tab 栏
                        subTabBar
                            .padding(.top, 22)
                            .padding(.horizontal, 16)

                        // Tab 内容
                        subTabContent
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Spacer().frame(height: 100)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .avatarUpdated)) { _ in
                if let uid = authManager.currentUser?.id.uuidString {
                    localAvatar = AvatarStore.load(for: uid)
                }
            }
            .onAppear {
                if let uid = authManager.currentUser?.id.uuidString {
                    localAvatar = AvatarStore.load(for: uid)
                }
                guard !hasPreloaded else { return }

                hasPreloaded = true
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await subscriptionManager.loadSubscriptions()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await subscriptionManager.refreshSubscriptionStatus()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await dailyRewardManager.checkTodayStatus()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let list = try? await TerritoryManager.shared.loadMyTerritories() {
                        myTerritories = list
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await explorationStatsManager.refreshStats()
                    _ = try? await explorationStatsManager.getExplorationHistory(limit: 200)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await buildingManager.refreshBuildings()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    PurchaseManager.shared.startTransactionListenerIfNeeded()
                }
            }
        }
    }

    // MARK: - 头像 + 用户名 + 身份

    private var headerSection: some View {
        VStack(spacing: 10) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.5, green: 0.3, blue: 0.9),
                                Color(red: 0.3, green: 0.5, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.purple.opacity(0.5), radius: 14)

                if let img = localAvatar {
                    // 本地自定义照片
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else if let icon = authManager.currentUser?.userMetadata["avatar_icon"]?.stringValue,
                          icon != "person.fill" {
                    Image(systemName: icon)
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                } else {
                    Text(avatarText)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // 用户名
            Text(displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 身份徽章
            identityBadge
        }
        .frame(maxWidth: .infinity)
    }

    /// 身份徽章
    private var identityBadge: some View {
        let tier = subscriptionManager.currentTier
        let (label, bg): (String, Color) = {
            switch tier {
            case .free:     return ("幸存者", Color(red: 0.35, green: 0.28, blue: 0.18))
            case .explorer: return ("探索者", Color(red: 0.1, green: 0.35, blue: 0.55))
            case .lord:     return ("领主",   Color(red: 0.5, green: 0.38, blue: 0.05))
            }
        }()
        let textColor: Color = {
            switch tier {
            case .free:     return Color(red: 0.9, green: 0.75, blue: 0.45)
            case .explorer: return ApocalypseTheme.info
            case .lord:     return Color(red: 1, green: 0.85, blue: 0.2)
            }
        }()

        return Text(LocalizedStringKey(label))
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(bg))
    }

    // MARK: - 内联统计行（存活 | 领地 | 建筑）

    private var statsInlineRow: some View {
        HStack(spacing: 0) {
            inlineStat(
                icon: "calendar.badge.clock",
                value: "\(survivalDays)\(String(localized: "天"))",
                label: "存活",
                color: ApocalypseTheme.info
            )
            statDivider
            inlineStat(
                icon: "flag.fill",
                value: "\(myTerritories.count)",
                label: "领地",
                color: ApocalypseTheme.info
            )
            statDivider
            inlineStat(
                icon: "building.2.fill",
                value: "\(buildingManager.playerBuildings.count)",
                label: "建筑",
                color: ApocalypseTheme.info
            )
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    private func inlineStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
            Text(verbatim: value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(ApocalypseTheme.textMuted.opacity(0.25))
            .frame(width: 1, height: 40)
    }

    /// 存活天数
    private var survivalDays: Int {
        guard let created = authManager.currentUser?.createdAt else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0)
    }

    // MARK: - 2×2 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // 编辑资料（蓝色）
                Button { showEditProfile = true } label: {
                    actionButtonLabel(
                        icon: "pencil",
                        title: "编辑资料",
                        color: Color(red: 0.18, green: 0.44, blue: 0.95)
                    )
                }

                // 设置（深灰）
                NavigationLink { SettingsDetailView() } label: {
                    actionButtonLabel(
                        icon: "gearshape.fill",
                        title: "设置",
                        color: Color(red: 0.22, green: 0.22, blue: 0.26)
                    )
                }
            }

            HStack(spacing: 10) {
                // 查看订阅（橙色）
                NavigationLink { SubscriptionView() } label: {
                    actionButtonLabel(
                        icon: "star.fill",
                        title: subscriptionManager.isSubscribed ? "管理订阅" : "查看订阅",
                        color: Color(red: 0.9, green: 0.55, blue: 0.1)
                    )
                }

                // 购买资源包（绿色）
                NavigationLink { StoreView() } label: {
                    actionButtonLabel(
                        icon: "cart.fill",
                        title: "购买资源包",
                        color: Color(red: 0.15, green: 0.68, blue: 0.38)
                    )
                }
            }
        }
    }

    private func actionButtonLabel(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .fontWeight(.medium)
            Text(LocalizedStringKey(title))
                .font(.callout)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(color))
    }

    // MARK: - 子 Tab 栏

    enum ProfileSubTab: String, CaseIterable {
        case stats    = "统计"
        case rank     = "排行榜"
        case achieve  = "成就"
        case physique = "体征"
    }

    private var subTabBar: some View {
        HStack(spacing: 4) {
            ForEach(ProfileSubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(LocalizedStringKey(tab.rawValue))
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.success)
                                : RoundedRectangle(cornerRadius: 10).fill(Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13).fill(ApocalypseTheme.cardBackground))
    }

    // MARK: - 子 Tab 内容

    @ViewBuilder
    private var subTabContent: some View {
        switch selectedTab {
        case .stats:    statsContent
        case .rank:     comingSoonPlaceholder(icon: "chart.bar.fill", title: "排行榜", subtitle: "即将推出")
        case .achieve:  comingSoonPlaceholder(icon: "trophy.fill", title: "成就系统", subtitle: "即将推出")
        case .physique: comingSoonPlaceholder(icon: "figure.walk", title: "体征数据", subtitle: "即将推出")
        }
    }

    /// 统计内容
    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 14) {

            // 标题
            VStack(alignment: .leading, spacing: 2) {
                Text("综合统计")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("数据驱动，砥砺前行")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 时间筛选器
            HStack(spacing: 0) {
                ForEach(StatsTimeFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            statsTimeFilter = filter
                        }
                    } label: {
                        Text(LocalizedStringKey(filter.rawValue))
                            .font(.subheadline)
                            .fontWeight(statsTimeFilter == filter ? .semibold : .regular)
                            .foregroundColor(statsTimeFilter == filter ? .white : ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                statsTimeFilter == filter
                                    ? RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.info)
                                    : RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                            )
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground))

            // 距离 + 面积 主指标卡
            HStack(spacing: 10) {
                bigMetricCard(
                    icon: "figure.walk",
                    iconColor: ApocalypseTheme.info,
                    value: filteredDistance,
                    label: "距离"
                )
                bigMetricCard(
                    icon: "map.fill",
                    iconColor: ApocalypseTheme.success,
                    value: filteredArea,
                    label: "面积"
                )
            }

            // 次级数据网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                miniStatCard(icon: "flag.fill",       iconColor: ApocalypseTheme.primary, value: "\(myTerritories.count)",                   label: "圈地总数")
                miniStatCard(icon: "building.2.fill", iconColor: ApocalypseTheme.info,    value: "\(buildingManager.playerBuildings.count)", label: "建筑总数")
            }

            // 每日礼包（订阅用户）
            if subscriptionManager.isSubscribed {
                NavigationLink { DailyRewardView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.title3)
                            .foregroundColor(ApocalypseTheme.warning)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.warning.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每日礼包")
                                .font(.callout).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Text(dailyRewardManager.hasClaimedToday ? "今日已领取" : "今日礼包待领取")
                                .font(.caption)
                                .foregroundColor(dailyRewardManager.hasClaimedToday ? ApocalypseTheme.textSecondary : ApocalypseTheme.warning)
                        }
                        Spacer()
                        if !dailyRewardManager.hasClaimedToday {
                            Circle().fill(ApocalypseTheme.danger).frame(width: 8, height: 8)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(14)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                }
            }

            // 呼号设置
            NavigationLink { CallsignEditView().environmentObject(authManager) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3).foregroundColor(ApocalypseTheme.info)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.info.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("呼号设置").font(.callout).fontWeight(.medium).foregroundColor(ApocalypseTheme.textPrimary)
                        Text(CommunicationManager.shared.userCallsign ?? "未设置呼号")
                            .font(.caption)
                            .foregroundColor(CommunicationManager.shared.userCallsign == nil ? ApocalypseTheme.warning : ApocalypseTheme.info)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            }

            // 查看详细统计
            NavigationLink {
                ExplorationLogView()
            } label: {
                HStack {
                    Text("查看详细统计")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.info)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.info)
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// 时间筛选后的探索距离
    private var filteredDistance: String {
        let history = explorationStatsManager.history
        let filtered: [ExplorationHistoryItem]
        if let start = statsTimeFilter.startDate {
            filtered = history.filter { $0.startTime >= start }
        } else {
            filtered = history
        }
        let total = filtered.reduce(0.0) { $0 + $1.distance }
        if total >= 1000 {
            return String(format: "%.1f km", total / 1000)
        }
        return String(format: "%.0f m", total)
    }

    /// 时间筛选后的领地面积
    private var filteredArea: String {
        let isoFormatter = ISO8601DateFormatter()
        let filtered: [Territory]
        if let start = statsTimeFilter.startDate {
            filtered = myTerritories.filter { t in
                guard let dateStr = t.completedAt ?? t.createdAt,
                      let date = isoFormatter.date(from: dateStr) else { return false }
                return date >= start
            }
        } else {
            filtered = myTerritories
        }
        let total = filtered.reduce(0.0) { $0 + $1.area }
        if total >= 1_000_000 {
            return String(format: "%.2f km²", total / 1_000_000)
        }
        return String(format: "%.0f m²", total)
    }

    private func bigMetricCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
            Text(verbatim: value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    private func miniStatCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: value)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(LocalizedStringKey(label))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func comingSoonPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text(LocalizedStringKey(subtitle))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - 辅助

    private var avatarText: String {
        if let first = displayName.first { return String(first).uppercased() }
        return "U"
    }

    private var displayName: String {
        if let username = authManager.currentUser?.userMetadata["username"]?.stringValue,
           !username.isEmpty { return username }
        if let email = authManager.currentUser?.email {
            return String(email.split(separator: "@").first ?? "")
        }
        return "用户"
    }
}

// MARK: - 编辑资料 Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    // 可选的预设头像图标（SF Symbols，末日风格）
    static let presetAvatarIcons: [String] = [
        "person.fill",
        "figure.walk",
        "figure.run",
        "figure.hiking",
        "figure.strengthtraining.traditional",
        "figure.martial.arts",
        "shield.fill",
        "bolt.fill",
        "star.fill",
        "crown.fill"
    ]

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedAvatarIcon: String = "person.fill"
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var pendingCustomImage: UIImage? = nil   // 待保存的自定义照片
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showErrorAlert = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── 基本信息 ──────────────────────────────
                        sectionLabel("基本信息")

                        TextField(LocalizedStringKey("用户名"), text: $username)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // ── 选择头像 ──────────────────────────────
                        sectionLabel("选择头像")

                        VStack(spacing: 0) {
                            // 预设图标网格
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Self.presetAvatarIcons, id: \.self) { icon in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedAvatarIcon = icon
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(selectedAvatarIcon == icon
                                                    ? Color(red: 0.18, green: 0.44, blue: 0.95)
                                                    : Color(white: 0.18))
                                                .frame(width: 56, height: 56)
                                            Image(systemName: icon)
                                                .font(.title3)
                                                .foregroundColor(selectedAvatarIcon == icon ? .white : Color(white: 0.55))
                                        }
                                    }
                                }
                            }
                            .padding(16)

                            // 自定义照片预览（选图后显示）
                            if let img = pendingCustomImage {
                                HStack(spacing: 12) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(ApocalypseTheme.info, lineWidth: 2))
                                    Text("已选择自定义头像")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.info)
                                    Spacer()
                                    Button {
                                        pendingCustomImage = nil
                                        selectedPhotoItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(ApocalypseTheme.textMuted)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }

                            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

                            // 从相册选择
                            PhotosPicker(selection: $selectedPhotoItem,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundColor(ApocalypseTheme.info)
                                    Text("从相册选择")
                                        .font(.callout)
                                        .foregroundColor(ApocalypseTheme.info)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                            }
                            .onChange(of: selectedPhotoItem) { item in
                                guard let item else { return }
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        // 裁剪为正方形并缩放到 300x300
                                        pendingCustomImage = img.squareCropped(size: 300)
                                    }
                                }
                            }
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                        // ── 个性签名 ──────────────────────────────
                        sectionLabel("个性签名")

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $bio)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 90)
                                .padding(12)

                            if bio.isEmpty {
                                Text("介绍一下自己吧…")
                                    .foregroundColor(ApocalypseTheme.textMuted)
                                    .padding(.top, 20)
                                    .padding(.leading, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                        // ── 账户信息 ──────────────────────────────
                        sectionLabel("账户信息")

                        VStack(spacing: 0) {
                            infoRow(
                                label: LocalizedStringKey("用户 ID"),
                                value: authManager.currentUser.map {
                                    String($0.id.uuidString.prefix(8)).uppercased() + "..."
                                } ?? "-"
                            )
                            Divider().background(ApocalypseTheme.textMuted.opacity(0.3)).padding(.leading, 16)
                            infoRow(
                                label: LocalizedStringKey("注册邮箱"),
                                value: authManager.currentUser?.email ?? "-"
                            )
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("编辑个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .font(.callout)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(ApocalypseTheme.cardBackground))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("保存")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(ApocalypseTheme.cardBackground))
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
            .alert("保存失败", isPresented: $showErrorAlert, presenting: saveError) { _ in
                Button("好") { }
            } message: { err in
                Text(err)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 组件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 逻辑

    private func loadCurrentValues() {
        let meta = authManager.currentUser?.userMetadata
        let stored = meta?["username"]?.stringValue ?? ""
        if stored.isEmpty, let email = authManager.currentUser?.email {
            username = String(email.split(separator: "@").first ?? "")
        } else {
            username = stored
        }
        bio = meta?["bio"]?.stringValue ?? ""
        selectedAvatarIcon = meta?["avatar_icon"]?.stringValue ?? "person.fill"
    }

    private func saveProfile() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true

        do {
            // 检查用户名是否可用（跳过自己当前的用户名）
            let currentUsername = authManager.currentUser?.userMetadata["username"]?.stringValue ?? ""
            if trimmed != currentUsername {
                let available: Bool = try await supabase
                    .rpc("check_username_available", params: ["p_username": trimmed])
                    .execute()
                    .value
                if !available {
                    saveError = "用户名「\(trimmed)」已被使用，请换一个"
                    showErrorAlert = true
                    isSaving = false
                    return
                }
            }

            // 更新 auth metadata
            try await supabase.auth.update(
                user: Auth.UserAttributes(data: [
                    "username":    .string(trimmed),
                    "bio":         .string(bio),
                    "avatar_icon": .string(selectedAvatarIcon)
                ])
            )

            // 更新 profiles 表
            if let userId = authManager.currentUser?.id {
                try await supabase
                    .from("profiles")
                    .update(["username": trimmed, "bio": bio])
                    .eq("id", value: userId.uuidString)
                    .execute()
            }

            // 保存自定义头像到本地
            if let img = pendingCustomImage,
               let uid = authManager.currentUser?.id.uuidString {
                AvatarStore.save(img, for: uid)
                NotificationCenter.default.post(name: .avatarUpdated, object: nil)
            }

            // 刷新本地 currentUser（避免 checkSession 对第三方登录用户产生副作用）
            if let session = try? await supabase.auth.session {
                await MainActor.run { authManager.currentUser = session.user }
            }

            isSaving = false
            dismiss()
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
            showErrorAlert = true
            isSaving = false
        }
    }
}

// MARK: - Notification 扩展

extension Notification.Name {
    static let avatarUpdated = Notification.Name("avatarUpdated")
}

// MARK: - UIImage 工具扩展

extension UIImage {
    /// 居中裁剪为正方形并缩放到指定边长
    func squareCropped(size: CGFloat) -> UIImage {
        let minSide = min(self.size.width, self.size.height)
        let cropRect = CGRect(
            x: (self.size.width  - minSide) / 2,
            y: (self.size.height - minSide) / 2,
            width: minSide, height: minSide
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
            if let cgImg = self.cgImage?.cropping(to: CGRect(
                x: cropRect.origin.x * self.scale,
                y: cropRect.origin.y * self.scale,
                width: cropRect.width  * self.scale,
                height: cropRect.height * self.scale
            )) {
                UIImage(cgImage: cgImg, scale: self.scale, orientation: self.imageOrientation)
                    .draw(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            }
        }
    }
}

// MARK: - 本地头像存储工具

enum AvatarStore {
    /// 保存头像图片到本地（按用户ID命名）
    static func save(_ image: UIImage, for userId: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = fileURL(for: userId)
        try? data.write(to: url, options: .atomic)
    }

    /// 读取本地头像
    static func load(for userId: String) -> UIImage? {
        let url = fileURL(for: userId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 删除本地头像
    static func delete(for userId: String) {
        try? FileManager.default.removeItem(at: fileURL(for: userId))
    }

    private static func fileURL(for userId: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar_\(userId).jpg")
    }
}

#Preview {
    ProfileTabView()
}
