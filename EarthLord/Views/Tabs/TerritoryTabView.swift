//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示和管理用户的领地
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - State

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showError = false

    /// 选中要删除的领地
    @State private var territoryToDelete: Territory?

    /// 是否显示删除确认
    @State private var showDeleteConfirm = false

    /// 是否正在删除
    @State private var isDeleting = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                // 主内容
                if isLoading && myTerritories.isEmpty {
                    // 首次加载
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await loadMyTerritories() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                // 首次加载
                if myTerritories.isEmpty {
                    Task { await loadMyTerritories() }
                }
            }
            .alert("删除领地", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    territoryToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let territory = territoryToDelete {
                        Task { await deleteTerritory(territory) }
                    }
                }
            } message: {
                if let territory = territoryToDelete {
                    Text("确定要删除这块 \(String(format: "%.0f", territory.area)) m² 的领地吗？此操作无法撤销。")
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 标题
            Text("暂无领地")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("前往地图页面，开始圈地来占领你的第一块领地吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 刷新按钮
            Button(action: {
                Task { await loadMyTerritories() }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(ApocalypseTheme.primary, lineWidth: 1)
                )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 领地列表视图

    private var territoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 统计卡片
                statsCard

                // 领地列表
                ForEach(myTerritories) { territory in
                    NavigationLink(destination: TerritoryDetailView(
                        territory: territory,
                        onDelete: {
                            Task { await deleteTerritory(territory) }
                        }
                    )) {
                        TerritoryCard(territory: territory)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await loadMyTerritories()
        }
    }

    // MARK: - 统计卡片

    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            StatItem(
                value: "\(myTerritories.count)",
                label: "领地数量",
                icon: "flag.fill"
            )

            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 总面积
            StatItem(
                value: formatArea(totalArea),
                label: "总面积",
                icon: "square.dashed"
            )
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化面积显示
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else if area >= 10_000 {
            return String(format: "%.1f 万m²", area / 10_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    // MARK: - 数据加载

    /// 加载我的领地
    private func loadMyTerritories() async {
        // 检查登录状态
        guard AuthManager.shared.isAuthenticated else {
            errorMessage = "请先登录"
            showError = true
            return
        }

        isLoading = true

        do {
            myTerritories = try await TerritoryManager.shared.loadMyTerritories()
            // 按创建时间降序排列
            myTerritories.sort { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    /// 删除领地
    private func deleteTerritory(_ territory: Territory) async {
        isDeleting = true

        do {
            try await TerritoryManager.shared.deleteTerritory(id: territory.id)

            // 从列表中移除
            await MainActor.run {
                myTerritories.removeAll { $0.id == territory.id }
                territoryToDelete = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "删除失败: \(error.localizedDescription)"
                showError = true
            }
        }

        isDeleting = false
    }
}

// MARK: - 统计项组件

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 领地卡片组件

private struct TerritoryCard: View {
    let territory: Territory

    /// 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：名称和箭头
            HStack {
                // 领地名称或默认名称
                Text(territory.name ?? "未命名领地")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 导航箭头
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 详情信息
            HStack(spacing: 24) {
                // 面积
                DetailItem(
                    icon: "square.dashed",
                    value: String(format: "%.0f m²", territory.area)
                )

                // 点数
                if let pointCount = territory.pointCount {
                    DetailItem(
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        value: "\(pointCount) 个点"
                    )
                }

                Spacer()
            }

            // 创建时间
            if let createdAt = territory.createdAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(formatDate(createdAt))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 格式化日期字符串
    private func formatDate(_ isoString: String) -> String {
        // ISO8601 格式解析
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: isoString) {
            return dateFormatter.string(from: date)
        }

        // 尝试不带毫秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            return dateFormatter.string(from: date)
        }

        return isoString
    }
}

// MARK: - 详情项组件

private struct DetailItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
