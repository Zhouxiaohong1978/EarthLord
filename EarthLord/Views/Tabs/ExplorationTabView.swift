//
//  ExplorationTabView.swift
//  EarthLord
//
//  资源模块入口 Tab
//  包含分段控制器：POI / 背包 / 已购 / 领地 / 交易
//

import SwiftUI
import CoreLocation

// MARK: - 资源页分段类型

enum ResourceSegment: String, CaseIterable {
    case poi = "废墟列表"
    case backpack = "背包"
    case warehouse = "领地物品"
    case mailbox = "邮箱"
    case trade = "交易"
}

// MARK: - 主视图

struct ExplorationTabView: View {
    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部标题区域
                    headerView

                    // 分段选择器
                    segmentedPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 内容区域
                    contentView
                }
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMailbox)) { _ in
                // 切换到邮箱分段
                withAnimation {
                    selectedSegment = .mailbox
                }
            }
        }
    }

    // MARK: - 顶部标题

    private var headerView: some View {
        HStack {
            Text(LocalizedStringKey("资源"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(LocalizedStringKey(segment.rawValue))
                        .font(.system(size: 15, weight: selectedSegment == segment ? .semibold : .medium))
                        .foregroundColor(selectedSegment == segment ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSegment == segment ?
                                ApocalypseTheme.cardBackground :
                                Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIContentView()
        case .backpack:
            BackpackContentView()
        case .warehouse:
            WarehouseContentView()
        case .mailbox:
            MailboxContentView()
        case .trade:
            TradeContentView()
        }
    }
}

// MARK: - 邮箱内容视图（嵌入资源页面）

struct MailboxContentView: View {
    @StateObject private var mailboxManager = MailboxManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if mailboxManager.isLoading && mailboxManager.mails.isEmpty {
                loadingView
            } else if mailboxManager.mails.isEmpty {
                emptyView
            } else {
                mailListView
            }
        }
        .task {
            await mailboxManager.loadMails()
            await WarehouseManager.shared.refreshItems()
        }
    }

    // MARK: - 邮件列表

    private var mailListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(mailboxManager.mails) { mail in
                    NavigationLink(destination: MailDetailView(mail: mail)) {
                        MailItemRow(mail: mail)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await mailboxManager.loadMails()
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(LocalizedStringKey("加载邮件..."))
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(LocalizedStringKey("邮箱为空"))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 提示卡片
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bag.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(LocalizedStringKey("购买的物资包物品将发放到此处"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                    Text(LocalizedStringKey("订阅所获得的每日礼包将发放到此处"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }
                Divider().background(ApocalypseTheme.primary.opacity(0.3))
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(LocalizedStringKey("收到物品后可领取进背包或直接存入仓库"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                    Spacer()
                }
            }
            .padding(14)
            .background(ApocalypseTheme.primary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.primary.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - POI 排序选项

enum POISortOption: String, CaseIterable {
    case distance = "按距离"
    case discovered = "已发现优先"
    case type = "按类型"
}

// MARK: - POI 内容视图

struct POIContentView: View {

    @ObservedObject private var explorationManager = ExplorationManager.shared
    @ObservedObject private var locationManager = LocationManager.shared

    @State private var selectedFilter: POIFilterType = .all
    @State private var sortOption: POISortOption = .distance
    @State private var listAppeared = false

    // MARK: - 计算属性

    private var hasAnyPOIs: Bool {
        !explorationManager.visiblePOIs.isEmpty
    }

    private var sortedAndFilteredPOIs: [POI] {
        var pois = explorationManager.visiblePOIs
        if let type = selectedFilter.poiType {
            pois = pois.filter { $0.type == type }
        }
        switch sortOption {
        case .distance:
            if let userCoord = locationManager.userLocation {
                let gcj02 = CoordinateConverter.wgs84ToGcj02(userCoord)
                let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)
                pois.sort {
                    let aLoc = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    let bLoc = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                    return userLoc.distance(from: aLoc) < userLoc.distance(from: bLoc)
                }
            }
        case .discovered:
            pois.sort { a, b in
                let aDiscovered = a.status != .undiscovered
                let bDiscovered = b.status != .undiscovered
                if aDiscovered != bDiscovered { return aDiscovered }
                return false
            }
        case .type:
            pois.sort { $0.type.rawValue < $1.type.rawValue }
        }
        return pois
    }

    private var scavengedCount: Int { explorationManager.visiblePOIs.filter { explorationManager.isCoolingDown($0) }.count }

    private func distanceString(for poi: POI) -> String? {
        guard let userCoord = locationManager.userLocation else { return nil }
        let gcj02 = CoordinateConverter.wgs84ToGcj02(userCoord)
        let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)
        let poiLoc = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        let meters = userLoc.distance(from: poiLoc)
        if meters < 1000 {
            return String(format: "直线 %.0fm", meters)
        } else {
            return String(format: "直线 %.1fkm", meters / 1000)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if explorationManager.isExploring {
                activeView(isCompleted: false)
            } else if hasAnyPOIs {
                activeView(isCompleted: true)
            } else {
                idleView
            }
        }
    }

    // MARK: - 空闲状态（无 POI 数据）

    private var idleView: some View {
        VStack(spacing: 0) {
            // 今日探索次数卡片
            if let limit = explorationManager.dailyExplorationLimit {
                let used = explorationManager.todayExplorationCount
                let exhausted = used >= limit
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16))
                        .foregroundColor(exhausted ? ApocalypseTheme.danger : ApocalypseTheme.primary)
                    Text(LocalizedStringKey("今日探索"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(exhausted ? ApocalypseTheme.danger : ApocalypseTheme.primary)
                                .frame(width: geo.size.width * CGFloat(min(used, limit)) / CGFloat(limit), height: 6)
                        }
                    }
                    .frame(width: 80, height: 6)
                    Text("\(used)/\(limit)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(exhausted ? ApocalypseTheme.danger : ApocalypseTheme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer()

            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.bottom, 16)

            Text(LocalizedStringKey("暂无废墟数据"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(LocalizedStringKey("前往地图开始探索，搜寻附近的废墟残骸"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Button {
                NotificationCenter.default.post(name: .navigateToMapTab, object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 15))
                    Text(LocalizedStringKey("前往地图"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.primary))
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { explorationManager.refreshTodayExplorationCount() }
    }

    // MARK: - 有 POI 数据（探索中 / 探索结束）

    private func activeView(isCompleted: Bool) -> some View {
        VStack(spacing: 0) {
            // 状态栏
            statusBar(isCompleted: isCompleted)
                .padding(.top, 12)

            // 筛选 + 排序工具栏
            toolBar
                .padding(.top, 10)

            // 列表
            if sortedAndFilteredPOIs.isEmpty {
                emptyFilterView
            } else {
                poiList
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - 状态栏

    private func statusBar(isCompleted: Bool) -> some View {
        HStack(spacing: 8) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.success)
                Text(LocalizedStringKey("上次探索"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                Circle()
                    .fill(ApocalypseTheme.success)
                    .frame(width: 8, height: 8)
                Text(LocalizedStringKey("探索中"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)
            }

            if let result = explorationManager.explorationResult {
                Text("·")
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(formatDistance(result.distanceWalked))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("·")
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(result.rewardTier.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.primary)
            } else {
                Text("·")
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(formatDistance(explorationManager.totalDistance))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\(explorationManager.visiblePOIs.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(LocalizedStringKey("个废墟"))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                if scavengedCount > 0 {
                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(String(format: String(localized: "已搜%d"), scavengedCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - 筛选 + 排序工具栏

    private var toolBar: some View {
        HStack(spacing: 0) {
            // 筛选 chips（横向滚动）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(POIFilterType.allCases) { filter in
                        POIFilterChip(filter: filter, isSelected: selectedFilter == filter) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedFilter = filter }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // 排序下拉
            Menu {
                ForEach(POISortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation { sortOption = option }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(option.rawValue))
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                    Text(LocalizedStringKey(sortOption.rawValue))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                )
            }
            .padding(.trailing, 16)
        }
    }

    // MARK: - POI 列表

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(sortedAndFilteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    let isScavenged = explorationManager.isCoolingDown(poi)
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICardNew(poi: poi, isScavenged: isScavenged, distance: distanceString(for: poi))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isScavenged)
                    .opacity(listAppeared ? 1 : 0)
                    .offset(y: listAppeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.06), value: listAppeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear {
            if !listAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { listAppeared = true }
            }
        }
    }

    // MARK: - 筛选无结果

    private var emptyFilterView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(LocalizedStringKey("该类型暂无废墟"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDistance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1fkm", meters / 1000) : "\(Int(meters))m"
    }
}

// MARK: - POI 筛选按钮（带图标）

struct POIFilterChip: View {
    let filter: POIFilterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12))

                Text(filter.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - POI 筛选类型扩展

extension POIFilterType {
    var icon: String {
        switch self {
        case .all:           return "square.grid.2x2.fill"
        case .restaurant:    return "fork.knife"
        case .supermarket:   return "cart.fill"
        case .hospital:      return "cross.case.fill"
        case .pharmacy:      return "pills.fill"
        case .gasStation:    return "fuelpump.fill"
        case .electronics:   return "cpu.fill"
        case .factory:       return "building.2.fill"
        case .warehouse:     return "shippingbox.fill"
        case .residential:   return "house.fill"
        case .police:        return "shield.fill"
        case .buildingSupply: return "hammer.fill"
        case .park:          return "leaf.fill"
        }
    }
}

// MARK: - 新版 POI 卡片

struct POICardNew: View {
    let poi: POI
    var isScavenged: Bool = false
    var distance: String? = nil

    private var stripColor: Color {
        isScavenged ? ApocalypseTheme.textMuted.opacity(0.4) : poi.type.color
    }

    private var isUndiscovered: Bool { poi.status == .undiscovered }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧色条
            Rectangle()
                .fill(stripColor)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 10,
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            // 内容区
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(stripColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: poi.type.icon)
                        .font(.system(size: 19))
                        .foregroundColor(stripColor)
                }

                // 文字信息
                VStack(alignment: .leading, spacing: 5) {
                    Text(poi.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isScavenged ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(poi.type.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isScavenged ? ApocalypseTheme.textMuted : stripColor)

                        if isScavenged {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(LocalizedStringKey("已搜刮"))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(ApocalypseTheme.textMuted)
                        } else if !isUndiscovered {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(ApocalypseTheme.success)
                                    .frame(width: 5, height: 5)
                                Text(LocalizedStringKey("可搜刮"))
                                    .font(.system(size: 11))
                                    .foregroundColor(ApocalypseTheme.success)
                            }
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                Text(LocalizedStringKey("未发现"))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }

                Spacer()

                // 右侧：距离 + 箭头
                VStack(alignment: .trailing, spacing: 4) {
                    if let dist = distance {
                        Text(dist)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(isScavenged ? ApocalypseTheme.textMuted : ApocalypseTheme.textSecondary)
                    }
                    if !isScavenged {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(isScavenged ? 0.45 : 1.0)
    }
}

// MARK: - 背包内容视图

struct BackpackContentView: View {
    // MARK: - 状态

    /// 背包管理器
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 是否首次加载
    @State private var isFirstLoad = true

    @State private var searchText = ""
    @State private var selectedFilter: BackpackFilterType = .all
    @State private var animatedCapacity: Double = 0

    /// 当前容量（物品总数量）
    private var currentCapacity: Double {
        Double(inventoryManager.totalItemCount)
    }

    /// 背包上限（订阅档位决定）
    private var maxCapacity: Double {
        Double(inventoryManager.backpackCapacity)
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        guard maxCapacity > 0 else { return 0 }
        return currentCapacity / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表（同 itemId+customName 才合并）
    private var groupedFilteredItems: [(key: String, itemId: String, totalQuantity: Int, customName: String?)] {
        var items = inventoryManager.items

        if let category = selectedFilter.category {
            items = items.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else { return false }
                return definition.category == category
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.customName ?? MockExplorationData.getItemDefinition(by: item.itemId)?.name ?? item.itemId
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 按 itemId + customName 分组：相同名字的 AI 物品堆叠，不同名字的独立显示
        var grouped: [String: (itemId: String, quantity: Int, customName: String?)] = [:]
        for item in items {
            let groupKey = "\(item.itemId)|\(item.customName ?? "")"
            if let existing = grouped[groupKey] {
                grouped[groupKey] = (existing.itemId, existing.quantity + item.quantity, existing.customName)
            } else {
                grouped[groupKey] = (item.itemId, item.quantity, item.customName)
            }
        }

        // 按显示名排序
        return grouped.map { (key: $0.key, itemId: $0.value.itemId, totalQuantity: $0.value.quantity, customName: $0.value.customName) }
            .sorted { a, b in
                let nameA = a.customName ?? MockExplorationData.getItemDefinition(by: a.itemId)?.name ?? a.itemId
                let nameB = b.customName ?? MockExplorationData.getItemDefinition(by: b.itemId)?.name ?? b.itemId
                return nameA < nameB
            }
    }

    /// 筛选后的物品列表（兼容旧逻辑判断空状态）
    private var filteredItems: [BackpackItem] {
        inventoryManager.items.filter { item in
            guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else { return false }
            if let category = selectedFilter.category, definition.category != category { return false }
            if !searchText.isEmpty, !definition.name.localizedCaseInsensitiveContains(searchText) { return false }
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 容量状态卡
            capacityCard
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 搜索框
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 筛选工具栏
            filterToolbar
                .padding(.top, 12)

            // 物品列表
            if inventoryManager.isLoading && isFirstLoad {
                // 首次加载中
                loadingView
            } else if inventoryManager.items.isEmpty {
                // 背包完全为空
                emptyState
            } else if filteredItems.isEmpty {
                // 搜索/筛选无结果
                emptyState
            } else {
                itemList
                    .padding(.top, 8)
            }
        }
        .onAppear {
            // 首次加载背包数据
            if isFirstLoad {
                Task {
                    await inventoryManager.refreshInventory()
                    isFirstLoad = false
                }
            }

            // 容量动画
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedCapacity = currentCapacity
            }
        }
        .onChange(of: inventoryManager.items) { _ in
            // 数据变化时更新容量动画
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCapacity = currentCapacity
            }
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(LocalizedStringKey("背包容量"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                let totalQty = inventoryManager.totalItemCount
                let maxSlots = inventoryManager.backpackCapacity
                let slotsPercentage = Double(totalQty) / Double(maxSlots)
                let slotsColor: Color = slotsPercentage > 0.9 ? ApocalypseTheme.danger : (slotsPercentage > 0.7 ? ApocalypseTheme.warning : ApocalypseTheme.success)

                Text("\(totalQty) / \(maxSlots)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(slotsColor)
            }

            // 进度条
            GeometryReader { geometry in
                let totalQty = inventoryManager.totalItemCount
                let maxSlots = inventoryManager.backpackCapacity
                let slotsPercentage = Double(totalQty) / Double(maxSlots)
                let slotsColor: Color = slotsPercentage > 0.9 ? ApocalypseTheme.danger : (slotsPercentage > 0.7 ? ApocalypseTheme.warning : ApocalypseTheme.success)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(slotsColor)
                        .frame(width: geometry.size.width * min(slotsPercentage, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BackpackFilterType.allCases) { filter in
                    BackpackFilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(groupedFilteredItems, id: \.key) { group in
                    if let definition = MockExplorationData.getItemDefinition(by: group.itemId) {
                        BackpackItemCardNew(
                            itemId: group.itemId,
                            totalQuantity: group.totalQuantity,
                            definition: definition,
                            customName: group.customName,
                            onUse: {
                                Task { @MainActor in
                                    if let backpackItem = inventoryManager.items.first(where: {
                                        $0.itemId == group.itemId && $0.customName == group.customName
                                    }) {
                                        try? await PhysiqueManager.shared.useItem(backpackItem)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text(LocalizedStringKey("加载背包数据..."))
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(LocalizedStringKey("没有找到相关物品"))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 背包筛选按钮

struct BackpackFilterChip: View {
    let filter: BackpackFilterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12))

                Text(LanguageManager.shared.localizedString(for: filter.title))
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 新版背包物品卡片

struct BackpackItemCardNew: View {
    let itemId: String
    let totalQuantity: Int
    let definition: ItemDefinition
    var customName: String? = nil
    var onUse: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(definition.category.color.opacity(0.2))
                    .frame(width: 52, height: 52)

                Image(systemName: definition.category.icon)
                    .font(.system(size: 22))
                    .foregroundColor(definition.category.color)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称和数量
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customName ?? LanguageManager.shared.localizedString(for: definition.name))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()

                    Text("x\(totalQuantity)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 稀有度
                HStack(spacing: 8) {
                    Text(LanguageManager.shared.localizedString(for: definition.rarity.rawValue))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(definition.rarity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(definition.rarity.color.opacity(0.15))
                        )
                }
            }

            Spacer()

            // 使用按钮（仅食物/水/药品）
            if definition.category == .food || definition.category == .water || definition.category == .medical {
                Button {
                    onUse?()
                } label: {
                    Text(LanguageManager.shared.localizedString(for: "使用"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.primary)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

// MARK: - 占位内容视图

struct PlaceholderContentView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("\(title)功能开发中...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 交易内容视图

struct TradeContentView: View {
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var showCreateSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 头部统计
                headerStats
                    .padding(.top, 12)

                // 三入口卡片
                VStack(spacing: 12) {
                    // 交易市场
                    NavigationLink {
                        TradeMarketView()
                    } label: {
                        entryCard(
                            title: "交易市场",
                            subtitle: "浏览其他玩家的挂单",
                            icon: "storefront.fill",
                            iconColor: ApocalypseTheme.primary,
                            count: tradeManager.availableOffers.count,
                            countLabel: "可用挂单"
                        )
                    }

                    // 我的挂单
                    NavigationLink {
                        MyTradeOffersView()
                    } label: {
                        entryCard(
                            title: "我的挂单",
                            subtitle: "管理您发布的挂单",
                            icon: "list.bullet.rectangle.fill",
                            iconColor: ApocalypseTheme.info,
                            count: activeOffersCount,
                            countLabel: "进行中"
                        )
                    }

                    // 交易历史
                    NavigationLink {
                        TradeHistoryView()
                    } label: {
                        entryCard(
                            title: "交易历史",
                            subtitle: "查看已完成的交易",
                            icon: "clock.arrow.circlepath",
                            iconColor: ApocalypseTheme.success,
                            count: tradeManager.tradeHistory.count,
                            countLabel: "笔交易"
                        )
                    }
                }

                // 快捷发布按钮
                quickPublishButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .task {
            await tradeManager.refreshAll()
        }
    }

    // MARK: - 进行中的挂单数

    private var activeOffersCount: Int {
        tradeManager.myOffers.filter { $0.status == .active }.count
    }

    // MARK: - 头部统计

    private var headerStats: some View {
        HStack(spacing: 16) {
            tradeStatItem(
                value: "\(tradeManager.availableOffers.count)",
                label: LocalizedStringKey("市场挂单"),
                icon: "cart.fill",
                color: ApocalypseTheme.primary
            )

            tradeStatItem(
                value: "\(activeOffersCount)",
                label: LocalizedStringKey("我的挂单"),
                icon: "tag.fill",
                color: ApocalypseTheme.info
            )

            tradeStatItem(
                value: "\(tradeManager.tradeHistory.count)",
                label: LocalizedStringKey("交易次数"),
                icon: "arrow.left.arrow.right",
                color: ApocalypseTheme.success
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private func tradeStatItem(value: String, label: LocalizedStringKey, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 入口卡片

    private func entryCard(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        count: Int,
        countLabel: String
    ) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }

            // 标题和副标题
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 计数和箭头
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)

                Text(LocalizedStringKey(countLabel))
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 快捷发布按钮

    private var quickPublishButton: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))

                Text(LocalizedStringKey("发布新挂单"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary)
            )
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTradeOfferView()
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationTabView()
}

#Preview("背包") {
    ExplorationTabView()
}
