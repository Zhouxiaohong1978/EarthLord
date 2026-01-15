//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示周围可探索的地点，支持搜索和分类筛选
//

import SwiftUI

// MARK: - POI 类型配置

/// POI 类型的显示配置（颜色和图标）
extension POIType {
    /// 类型对应的颜色
    var color: Color {
        switch self {
        case .hospital:
            return Color.red
        case .supermarket:
            return Color.green
        case .restaurant:
            return Color.yellow
        case .factory:
            return Color.gray
        case .pharmacy:
            return Color.purple
        case .gasStation:
            return ApocalypseTheme.primary  // 橙色
        case .warehouse:
            return Color.brown
        case .residential:
            return Color.cyan
        case .police:
            return Color.blue
        case .military:
            return Color.yellow
        }
    }

    /// 类型对应的图标
    var icon: String {
        switch self {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .restaurant:
            return "fork.knife"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .residential:
            return "house.fill"
        case .police:
            return "shield.fill"
        case .military:
            return "target"
        }
    }
}

// MARK: - 筛选类型

/// 筛选选项枚举
enum POIFilterType: String, CaseIterable, Identifiable {
    case all = "全部"
    case hospital = "医院"
    case supermarket = "超市"
    case factory = "工厂"
    case pharmacy = "药店"
    case gasStation = "加油站"

    var id: String { rawValue }

    /// 转换为 POIType（全部返回 nil）
    var poiType: POIType? {
        switch self {
        case .all: return nil
        case .hospital: return .hospital
        case .supermarket: return .supermarket
        case .factory: return .factory
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        }
    }
}

// MARK: - 主视图

struct POIListView: View {
    // MARK: - 状态

    /// 当前选中的筛选类型
    @State private var selectedFilter: POIFilterType = .all

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮缩放状态
    @State private var isSearchButtonPressed = false

    /// 列表是否已显示（用于入场动画）
    @State private var listAppeared = false

    /// GPS 坐标（假数据）
    private let gpsCoordinate = (lat: 22.54, lng: 114.06)

    // MARK: - 计算属性

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
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表或空状态
                if MockExplorationData.poiList.isEmpty {
                    // 完全没有POI
                    emptyStateNoPOI
                } else if filteredPOIs.isEmpty {
                    // 筛选后没有结果
                    emptyStateNoFilterResult
                } else {
                    poiList
                        .padding(.top, 12)
                }
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 空状态：没有POI

    private var emptyStateNoPOI: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("附近暂无兴趣点")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击搜索按钮发现周围的废墟")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - 空状态：筛选无结果

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
        .padding(.horizontal, 32)
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
            Text("附近发现 \(filteredPOIs.count) 个地点")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
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

                Text(isSearching ? "搜索中..." : "搜索附近POI")
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
        .scaleEffect(isSearchButtonPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isSearchButtonPressed = true }
                .onEnded { _ in isSearchButtonPressed = false }
        )
        .disabled(isSearching)
    }

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 重置列表动画状态，准备重新播放
        listAppeared = false

        // 1.5秒后恢复正常并触发列表动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSearching = false
            }
            // 延迟一点触发列表入场动画
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
                    FilterChip(
                        title: filter.rawValue,
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
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICard(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            // 首次出现时触发动画
            if !listAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    listAppeared = true
                }
            }
        }
    }
}

// MARK: - 筛选按钮组件

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
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

// MARK: - POI 卡片组件

struct POICard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(poi.type.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: poi.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(poi.type.color)
            }

            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型
                Text(poi.type.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 状态标签
            VStack(alignment: .trailing, spacing: 4) {
                // 发现状态
                statusBadge(for: poi.status)

                // 危险等级
                if poi.dangerLevel >= 3 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("危险")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.warning)
                }
            }

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 根据状态返回对应的标签视图
    @ViewBuilder
    private func statusBadge(for status: POIStatus) -> some View {
        let (text, color) = statusInfo(for: status)

        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    /// 获取状态的文字和颜色
    private func statusInfo(for status: POIStatus) -> (String, Color) {
        switch status {
        case .undiscovered:
            return ("未发现", ApocalypseTheme.textMuted)
        case .discovered:
            return ("已发现", ApocalypseTheme.info)
        case .hasResources:
            return ("有物资", ApocalypseTheme.success)
        case .looted:
            return ("已搜空", ApocalypseTheme.textSecondary)
        case .dangerous:
            return ("危险", ApocalypseTheme.danger)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}

#Preview("POI Card") {
    VStack(spacing: 12) {
        POICard(poi: MockExplorationData.poiList[0])
        POICard(poi: MockExplorationData.poiList[1])
        POICard(poi: MockExplorationData.poiList[4])
    }
    .padding()
    .background(ApocalypseTheme.background)
}
