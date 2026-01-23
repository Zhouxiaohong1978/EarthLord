//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 全屏地图布局 + 建筑列表 + 操作菜单
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据（使用 @State 以支持重命名更新）
    @State var territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    // MARK: - State

    /// 是否显示信息面板
    @State private var showInfoPanel = true

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造确认页）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 是否显示重命名对话框
    @State private var showRenameDialog = false

    /// 新名称输入
    @State private var newTerritoryName = ""

    /// 是否正在重命名
    @State private var isRenaming = false

    /// 是否显示删除确认
    @State private var showDeleteConfirm = false

    /// 是否显示拆除确认
    @State private var showDemolishConfirm = false

    /// 要拆除的建筑
    @State private var buildingToDemolish: PlayerBuilding?

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showError = false

    /// 定时器（用于更新建造进度）
    @State private var timer: Timer?

    /// 环境变量 - 用于返回
    @Environment(\.dismiss) private var dismiss

    // MARK: - Managers

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - Computed Properties

    /// 领地坐标（原始 WGS-84）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 领地坐标（GCJ-02，用于位置选择器）
    private var territoryCoordinatesGCJ02: [CLLocationCoordinate2D] {
        CoordinateConverter.wgs84ToGcj02(territoryCoordinates)
    }

    /// 领地内的建筑
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 建筑模板字典
    private var templateDict: [String: BuildingTemplate] {
        var dict: [String: BuildingTemplate] = [:]
        for template in buildingManager.buildingTemplates {
            dict[template.templateId] = template
        }
        return dict
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territoryCoordinates: territoryCoordinates,
                buildings: territoryBuildings,
                templates: templateDict
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                TerritoryToolbarView(
                    onDismiss: { dismiss() },
                    onBuildingBrowser: { showBuildingBrowser = true },
                    showInfoPanel: $showInfoPanel
                )
                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        // 建筑浏览器 Sheet
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    // 延迟 0.3s 避免动画冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        // 建造确认页 Sheet（使用 item: 绑定）
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territoryCoordinatesGCJ02,
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { _ in
                    selectedTemplateForConstruction = nil
                    // 刷新建筑列表
                    Task {
                        try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                    }
                }
            )
        }
        // 重命名对话框
        .alert(String(localized: "重命名领地"), isPresented: $showRenameDialog) {
            TextField(String(localized: "新名称"), text: $newTerritoryName)
            Button(String(localized: "取消"), role: .cancel) {
                newTerritoryName = ""
            }
            Button(String(localized: "确定")) {
                Task { await renameTerritory() }
            }
            .disabled(newTerritoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(String(localized: "请输入新的领地名称"))
        }
        // 删除确认对话框
        .alert(String(localized: "删除领地"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "取消"), role: .cancel) {}
            Button(String(localized: "删除"), role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text(String(format: String(localized: "确定要删除这块 %.0f m² 的领地吗？此操作无法撤销。"), territory.area))
        }
        // 拆除确认对话框
        .alert(String(localized: "拆除建筑"), isPresented: $showDemolishConfirm) {
            Button(String(localized: "取消"), role: .cancel) {
                buildingToDemolish = nil
            }
            Button(String(localized: "拆除"), role: .destructive) {
                if let building = buildingToDemolish {
                    Task { await demolishBuilding(building) }
                }
            }
        } message: {
            if let building = buildingToDemolish {
                Text(String(format: String(localized: "确定要拆除 %@ 吗？此操作无法撤销。"), building.buildingName))
            }
        }
        // 错误提示
        .alert(String(localized: "错误"), isPresented: $showError) {
            Button(String(localized: "确定"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "未知错误"))
        }
    }

    // MARK: - 信息面板

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动指示器
            RoundedRectangle(cornerRadius: 2)
                .fill(ApocalypseTheme.textSecondary)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名称 + 齿轮按钮
                    territoryHeader

                    // 领地信息卡片
                    territoryInfoCard

                    // 建筑列表区域
                    buildingListSection

                    // 危险操作区域
                    dangerZone
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
        )
        .padding(.horizontal, 8)
    }

    /// 领地名称头部
    private var territoryHeader: some View {
        HStack {
            Text(territory.name ?? String(localized: "未命名领地"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 齿轮按钮（重命名）
            Button {
                newTerritoryName = territory.name ?? ""
                showRenameDialog = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
    }

    /// 领地信息卡片
    private var territoryInfoCard: some View {
        HStack(spacing: 0) {
            // 面积
            infoItem(
                icon: "square.dashed",
                value: String(format: "%.0f m²", territory.area),
                label: String(localized: "面积")
            )

            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)

            // 点数
            if let pointCount = territory.pointCount {
                infoItem(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    value: "\(pointCount)",
                    label: String(localized: "边界点")
                )

                Divider()
                    .frame(height: 40)
                    .background(ApocalypseTheme.textMuted)
            }

            // 建筑数量
            infoItem(
                icon: "building.2",
                value: "\(territoryBuildings.count)",
                label: String(localized: "建筑")
            )
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    /// 信息项
    private func infoItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 建筑列表区域
    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "建筑列表"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 建造按钮
                Button {
                    showBuildingBrowser = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text(String(localized: "建造"))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                    )
                }
            }

            if territoryBuildings.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.system(size: 32))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(String(localized: "暂无建筑"))
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(String(localized: "点击上方「建造」按钮开始建设"))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.background)
                )
            } else {
                // 建筑列表
                VStack(spacing: 8) {
                    ForEach(territoryBuildings) { building in
                        TerritoryBuildingRow(
                            building: building,
                            template: templateDict[building.templateId],
                            onUpgrade: {
                                Task { await upgradeBuilding(building) }
                            },
                            onDemolish: {
                                buildingToDemolish = building
                                showDemolishConfirm = true
                            }
                        )
                    }
                }
            }
        }
    }

    /// 危险操作区域
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "危险操作"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.danger)

            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(String(localized: "删除领地"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.danger)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Methods

    /// 加载数据
    private func loadData() {
        // 确保模板已加载
        if buildingManager.buildingTemplates.isEmpty {
            buildingManager.loadTemplates()
        }

        // 加载建筑列表
        Task {
            try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        }
    }

    /// 启动定时器（用于更新建造进度）
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 检查并完成建造
            Task {
                await buildingManager.checkAndCompleteConstructions()
            }
        }
    }

    /// 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 重命名领地
    private func renameTerritory() async {
        let name = newTerritoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isRenaming = true

        do {
            try await TerritoryManager.shared.updateTerritoryName(id: territory.id, name: name)

            await MainActor.run {
                // 更新本地对象
                territory = Territory(
                    id: territory.id,
                    userId: territory.userId,
                    name: name,
                    path: territory.path,
                    area: territory.area,
                    pointCount: territory.pointCount,
                    isActive: territory.isActive,
                    startedAt: territory.startedAt,
                    completedAt: territory.completedAt,
                    createdAt: territory.createdAt
                )

                newTerritoryName = ""
                isRenaming = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isRenaming = false
            }
        }
    }

    /// 升级建筑
    private func upgradeBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            await MainActor.run {
                buildingToDemolish = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                buildingToDemolish = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "preview-id",
            userId: "user-id",
            name: "我的第一块领地",
            path: [
                ["lat": 31.2304, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4747],
                ["lat": 31.2304, "lon": 121.4747]
            ],
            area: 1500,
            pointCount: 25,
            isActive: true,
            startedAt: "2025-01-08T10:00:00Z",
            completedAt: "2025-01-08T10:15:00Z",
            createdAt: "2025-01-08T10:15:30Z"
        )
    )
}
