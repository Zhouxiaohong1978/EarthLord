//
//  ExplorationTabView.swift
//  EarthLord
//
//  资源模块入口 Tab
//  包含分段控制器：POI / 背包 / 已购 / 领地 / 交易
//

import SwiftUI

// MARK: - 资源页分段类型

enum ResourceSegment: String, CaseIterable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
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
        }
    }

    // MARK: - 顶部标题

    private var headerView: some View {
        HStack {
            Text("资源")
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
                    Text(segment.rawValue)
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
        case .purchased:
            PlaceholderContentView(title: "已购", icon: "bag.fill")
        case .territory:
            PlaceholderContentView(title: "领地", icon: "flag.fill")
        case .trade:
            PlaceholderContentView(title: "交易", icon: "arrow.left.arrow.right")
        }
    }
}

// MARK: - POI 内容视图

struct POIContentView: View {
    // MARK: - 状态

    /// 当前选中的筛选类型
    @State private var selectedFilter: POIFilterType = .all

    /// 是否正在搜索
    @State private var isSearching = false

    /// 列表是否已显示
    @State private var listAppeared = false

    /// GPS 坐标（假数据）
    private let gpsCoordinate = (lat: 22.54, lng: 114.06)

    // MARK: - 计算属性

    /// 已发现的POI数量
    private var discoveredCount: Int {
        MockExplorationData.poiList.filter { $0.status != .undiscovered }.count
    }

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if selectedFilter == .all {
            return MockExplorationData.poiList
        } else if let type = selectedFilter.poiType {
            return MockExplorationData.poiList.filter { $0.type == type }
        }
        return MockExplorationData.poiList
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            statusBar
                .padding(.top, 12)

            // 搜索按钮
            searchButton
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 筛选工具栏
            filterToolbar
                .padding(.top, 12)

            // POI 列表
            if filteredPOIs.isEmpty {
                emptyStateNoFilterResult
            } else {
                poiList
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(String(format: "%.2f, %.2f", gpsCoordinate.lat, gpsCoordinate.lng))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isSearching ? "搜索中..." : "搜索附近 POI")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.primaryDark : ApocalypseTheme.primary)
            )
        }
        .disabled(isSearching)
    }

    /// 执行搜索
    private func performSearch() {
        isSearching = true
        listAppeared = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSearching = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                listAppeared = true
            }
        }
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(POIFilterType.allCases) { filter in
                    POIFilterChip(
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

    // MARK: - POI 列表

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICardNew(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(poi.status == .undiscovered)
                    .opacity(listAppeared ? 1 : 0)
                    .offset(y: listAppeared ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.35).delay(Double(index) * 0.08),
                        value: listAppeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear {
            if !listAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    listAppeared = true
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateNoFilterResult: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到该类型的地点")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试选择其他分类")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
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

                Text(filter.rawValue)
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
        case .all: return "square.grid.2x2.fill"
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        }
    }
}

// MARK: - 新版 POI 卡片

struct POICardNew: View {
    let poi: POI

    /// 是否为未发现状态
    private var isUndiscovered: Bool {
        poi.status == .undiscovered
    }

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(isUndiscovered ? ApocalypseTheme.textMuted.opacity(0.2) : poi.type.color.opacity(0.2))
                    .frame(width: 52, height: 52)

                Image(systemName: poi.type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isUndiscovered ? ApocalypseTheme.textMuted : poi.type.color)
            }

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUndiscovered ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)

                // 状态行
                HStack(spacing: 10) {
                    // 类型
                    Text(poi.type.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isUndiscovered ? ApocalypseTheme.textMuted : poi.type.color)

                    if !isUndiscovered {
                        // 发现状态
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text("已发现")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        // 物资状态
                        resourceStatusView
                    } else {
                        // 未发现
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 10))
                            Text("未发现")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }

            Spacer()

            // 右侧图标
            if isUndiscovered {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(isUndiscovered ? 0.7 : 1.0)
    }

    /// 物资状态视图
    @ViewBuilder
    private var resourceStatusView: some View {
        switch poi.status {
        case .hasResources:
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 10))
                Text("有物资")
                    .font(.system(size: 12))
            }
            .foregroundColor(ApocalypseTheme.success)
        case .looted:
            HStack(spacing: 4) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 10))
                Text("已空")
                    .font(.system(size: 12))
            }
            .foregroundColor(ApocalypseTheme.textMuted)
        case .discovered:
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 10))
                Text("待搜索")
                    .font(.system(size: 12))
            }
            .foregroundColor(ApocalypseTheme.info)
        default:
            EmptyView()
        }
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

    private let maxCapacity: Double = 100

    /// 当前容量（从背包管理器动态获取）
    private var currentCapacity: Double {
        Double(inventoryManager.totalItemCount)
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        currentCapacity / maxCapacity
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

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = inventoryManager.items

        if let category = selectedFilter.category {
            items = items.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                    return false
                }
                return definition.category == category
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                    return false
                }
                return definition.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
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

                    Text("背包容量")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                Text(String(format: "%.1f / %.0f kg", animatedCapacity, maxCapacity))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * (animatedCapacity / maxCapacity), height: 8)
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
                ForEach(filteredItems) { item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                        BackpackItemCardNew(item: item, definition: definition)
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

            Text("加载背包数据...")
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

            Text("没有找到相关物品")
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

                Text(filter.title)
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
    let item: BackpackItem
    let definition: ItemDefinition

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
                    Text(definition.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 重量、品质、稀有度
                HStack(spacing: 8) {
                    // 重量
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(quality.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(quality.color.opacity(0.15))
                            )
                    }

                    // 稀有度
                    Text(definition.rarity.rawValue)
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

            // 操作按钮
            VStack(spacing: 6) {
                Button {
                    print("使用: \(definition.name)")
                } label: {
                    Text("使用")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.primary)
                        )
                }

                Button {
                    print("存储: \(definition.name)")
                } label: {
                    Text("存储")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 48, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
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

// MARK: - Preview

#Preview {
    ExplorationTabView()
}

#Preview("背包") {
    ExplorationTabView()
}
