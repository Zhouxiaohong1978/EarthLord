//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页 - 地图选点、资源确认、执行建造
//

import SwiftUI
import CoreLocation

/// 建造确认视图
struct BuildingPlacementView: View {
    /// 建筑模板
    let template: BuildingTemplate
    /// 领地 ID
    let territoryId: String
    /// 领地边界坐标（GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]
    /// 关闭回调
    var onDismiss: () -> Void
    /// 建造完成回调
    var onConstructionStarted: (PlayerBuilding) -> Void

    /// 建筑管理器
    @ObservedObject private var buildingManager = BuildingManager.shared
    /// 背包管理器
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 选中的建造位置
    @State private var selectedLocation: CLLocationCoordinate2D?
    /// 是否显示位置选择器
    @State private var showLocationPicker = false
    /// 是否正在建造
    @State private var isBuilding = false
    /// 错误消息
    @State private var errorMessage: String?
    /// 是否显示错误提示
    @State private var showError = false

    /// 建造检查结果
    private var canBuildResult: CanBuildResult {
        buildingManager.canBuildWithInventory(template: template, territoryId: territoryId)
    }

    /// 是否可以建造
    private var canBuild: Bool {
        canBuildResult.canBuild && selectedLocation != nil
    }

    /// 玩家资源（按 itemId 分组）
    private var playerResources: [String: Int] {
        var resources: [String: Int] = [:]
        for item in inventoryManager.items {
            resources[item.itemId, default: 0] += item.quantity
        }
        return resources
    }

    /// 已有建筑列表
    private var existingBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territoryId }
    }

    /// 建筑模板字典
    private var templateDict: [String: BuildingTemplate] {
        var dict: [String: BuildingTemplate] = [:]
        for tmpl in buildingManager.buildingTemplates {
            dict[tmpl.templateId] = tmpl
        }
        return dict
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑预览
                    buildingPreview

                    // 建造位置
                    locationSection

                    // 资源消耗
                    resourcesSection

                    // 建造时间
                    buildTimeSection

                    // 数量限制提示
                    if canBuildResult.isMaxReached {
                        maxReachedWarning
                    }

                    Spacer(minLength: 20)

                    // 确认建造按钮
                    buildButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(String(localized: "确认建造"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: templateDict,
                    onSelectLocation: { coord in
                        selectedLocation = coord
                        showLocationPicker = false
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
            }
            .alert(String(localized: "建造失败"), isPresented: $showError) {
                Button(String(localized: "知道了"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? String(localized: "未知错误"))
            }
        }
        .onAppear {
            // 刷新背包数据
            Task {
                await inventoryManager.refreshInventory()
            }
        }
    }

    // MARK: - 子视图

    /// 建筑预览
    private var buildingPreview: some View {
        HStack(spacing: 16) {
            // 建筑图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 64, height: 64)

                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .foregroundColor(template.category.color)
            }

            // 建筑信息
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    // 分类标签
                    HStack(spacing: 4) {
                        Image(systemName: template.category.icon)
                            .font(.system(size: 10))
                        Text(template.category.displayName)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(template.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(template.category.color.opacity(0.15))
                    )

                    // 数量显示
                    Text("\(canBuildResult.currentCount)/\(canBuildResult.maxCount)")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 建造位置区域
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "建造位置"))

            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.system(size: 20))
                        .foregroundColor(selectedLocation != nil ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        if let location = selectedLocation {
                            Text(String(localized: "已选择位置"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ApocalypseTheme.success)

                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        } else {
                            Text(String(localized: "点击选择建造位置"))
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedLocation != nil ? ApocalypseTheme.success.opacity(0.5) : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// 资源消耗区域
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "所需资源"))

            VStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    if let requiredAmount = template.requiredResources[resourceId] {
                        let currentAmount = playerResources[resourceId] ?? 0

                        ResourceRow(
                            resourceName: resourceDisplayName(for: resourceId),
                            requiredAmount: requiredAmount,
                            currentAmount: currentAmount,
                            icon: resourceIcon(for: resourceId)
                        )
                    }
                }
            }
        }
    }

    /// 建造时间区域
    private var buildTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "建造时间"))

            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(template.formattedBuildTime)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    /// 数量限制警告
    private var maxReachedWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.warning)

            Text(String(format: String(localized: "该建筑已达到领地上限 (%d)"), template.maxPerTerritory))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.warning)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    /// 确认建造按钮
    private var buildButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack(spacing: 8) {
                if isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "hammer.fill")
                }
                Text(isBuilding ? String(localized: "建造中...") : String(localized: "确认建造"))
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canBuild && !isBuilding ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            )
        }
        .disabled(!canBuild || isBuilding)
        .buttonStyle(.plain)
    }

    // MARK: - 辅助方法

    /// 区域标题
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ApocalypseTheme.textPrimary)
    }

    /// 开始建造
    private func startConstruction() async {
        guard let location = selectedLocation else { return }

        isBuilding = true

        do {
            let building = try await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territoryId,
                location: location
            )

            await MainActor.run {
                isBuilding = false
                onConstructionStarted(building)
            }
        } catch {
            await MainActor.run {
                isBuilding = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "1",
        templateId: "campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        description: "提供温暖和照明",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 300,
        maxPerTerritory: 3,
        maxLevel: 3
    )

    BuildingPlacementView(
        template: sampleTemplate,
        territoryId: "test-territory",
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
