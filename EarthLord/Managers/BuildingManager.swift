//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器 - 管理建筑的建造、升级和查询
//

import Foundation
import Supabase
import CoreLocation
import Combine

// MARK: - BuildingManager

/// 建筑管理器（单例）
@MainActor
final class BuildingManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 所有建筑模板
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 当前领地的建筑
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 日志器
    private let logger = ExplorationLogger.shared

    // MARK: - Initialization

    private init() {
        logger.log("BuildingManager 初始化完成", type: .info)
    }

    // MARK: - Template Methods

    /// 从 Bundle 加载建筑模板
    func loadTemplates() {
        logger.log("开始加载建筑模板...", type: .info)

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            logger.log("找不到 building_templates.json 文件", type: .error)
            errorMessage = "找不到建筑模板配置文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let container = try decoder.decode(BuildingTemplateContainer.self, from: data)
            buildingTemplates = container.templates
            logger.log("成功加载 \(buildingTemplates.count) 个建筑模板", type: .success)
        } catch {
            logger.logError("加载建筑模板失败", error: error)
            errorMessage = "加载建筑模板失败: \(error.localizedDescription)"
        }
    }

    /// 根据 ID 获取建筑模板
    /// - Parameter templateId: 模板 ID
    /// - Returns: 建筑模板，未找到返回 nil
    func getTemplate(by templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    /// 根据分类获取建筑模板
    /// - Parameter category: 建筑分类
    /// - Returns: 该分类的建筑模板列表
    func getTemplates(by category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category }
    }

    // MARK: - Build Check Methods

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家资源（itemId -> quantity）
    /// - Returns: 建造检查结果
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> CanBuildResult {
        // 检查 blueprint 解锁条件
        // lord_banner 需要 blueprint_basic，lord_command 需要 blueprint_epic
        if template.templateId == "lord_banner" {
            let hasBlueprint = (playerResources["blueprint_basic"] ?? 0) >= 1
            if !hasBlueprint {
                logger.log("建造检查失败：\(template.name) 需要基础图纸解锁", type: .warning)
                return .insufficientResources(["blueprint_basic": 1], currentCount: 0, maxCount: template.maxPerTerritory)
            }
        }
        if template.templateId == "lord_command" {
            let hasBlueprint = (playerResources["blueprint_epic"] ?? 0) >= 1
            if !hasBlueprint {
                logger.log("建造检查失败：\(template.name) 需要史诗图纸解锁", type: .warning)
                return .insufficientResources(["blueprint_epic": 1], currentCount: 0, maxCount: template.maxPerTerritory)
            }
        }

        // 检查领地内该建筑的数量
        let currentCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if currentCount >= template.maxPerTerritory {
            logger.log("建造检查失败：\(template.name) 已达到领地上限 (\(currentCount)/\(template.maxPerTerritory))", type: .warning)
            return .maxReached(currentCount: currentCount, maxCount: template.maxPerTerritory)
        }

        // 检查资源是否充足
        var missingResources: [String: Int] = [:]

        for (resourceId, requiredAmount) in template.requiredResources {
            let currentAmount = playerResources[resourceId] ?? 0
            if currentAmount < requiredAmount {
                missingResources[resourceId] = requiredAmount - currentAmount
            }
        }

        if !missingResources.isEmpty {
            let missingList = missingResources.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            logger.log("建造检查失败：资源不足，还需要 \(missingList)", type: .warning)
            return .insufficientResources(missingResources, currentCount: currentCount, maxCount: template.maxPerTerritory)
        }

        logger.log("建造检查通过：\(template.name) (\(currentCount)/\(template.maxPerTerritory))", type: .success)
        return .success(currentCount: currentCount, maxCount: template.maxPerTerritory)
    }

    /// 使用卫星模块加速建造（每个-2小时，最多3个）
    func applySatelliteModuleSpeedup(buildingId: UUID, moduleCount: Int) async throws {
        guard moduleCount > 0 else { return }
        let count = min(moduleCount, 3)

        // 消耗背包中的 satellite_module
        let items = InventoryManager.shared.items.filter { $0.itemId == "satellite_module" }
        var remaining = count
        for item in items {
            guard remaining > 0 else { break }
            let use = min(item.quantity, remaining)
            try await InventoryManager.shared.useItem(inventoryId: item.id, quantity: use)
            remaining -= use
        }

        // 更新建筑完成时间（每个减2小时）
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }),
              let currentCompletedAt = playerBuildings[index].buildCompletedAt else { return }

        let reduction = TimeInterval(count * 7200) // 每个减2小时
        let newCompletedAt = max(Date(), currentCompletedAt - reduction)

        try await supabase
            .from("player_buildings")
            .update(["build_completed_at": newCompletedAt.ISO8601Format()])
            .eq("id", value: buildingId.uuidString)
            .execute()

        playerBuildings[index].buildCompletedAt = newCompletedAt
        logger.log("卫星模块加速：使用\(count)个卫星模块，缩短\(count * 2)小时", type: .success)
    }

    /// 使用建造加速令缩短当前建造时间（每个-30分钟，最多5个）
    func applyBuildSpeedup(buildingId: UUID, tokenCount: Int) async throws {
        guard tokenCount > 0 else { return }
        let count = min(tokenCount, 5)

        // 消耗背包中的 build_speedup
        let items = InventoryManager.shared.items.filter { $0.itemId == "build_speedup" }
        var remaining = count
        for item in items {
            guard remaining > 0 else { break }
            let use = min(item.quantity, remaining)
            try await InventoryManager.shared.useItem(inventoryId: item.id, quantity: use)
            remaining -= use
        }

        // 更新建筑完成时间
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }),
              let currentCompletedAt = playerBuildings[index].buildCompletedAt else { return }

        let reduction = TimeInterval(count * 1800) // 每个减30分钟
        let newCompletedAt = max(Date(), currentCompletedAt - reduction)

        try await supabase
            .from("player_buildings")
            .update(["build_completed_at": newCompletedAt.ISO8601Format()])
            .eq("id", value: buildingId.uuidString)
            .execute()

        playerBuildings[index].buildCompletedAt = newCompletedAt
        logger.log("建造加速：使用\(count)个加速令，缩短\(count * 30)分钟", type: .success)
    }

    /// 使用背包 + 仓库合并资源检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    /// - Returns: 建造检查结果
    func canBuildWithInventory(
        template: BuildingTemplate,
        territoryId: String
    ) -> CanBuildResult {
        // 背包资源
        var playerResources: [String: Int] = [:]
        for item in InventoryManager.shared.items {
            playerResources[item.itemId, default: 0] += item.quantity
        }
        // 仓库资源（补充背包不足的部分）
        for item in WarehouseManager.shared.items {
            playerResources[item.itemId, default: 0] += item.quantity
        }
        return canBuild(template: template, territoryId: territoryId, playerResources: playerResources)
    }

    // MARK: - Construction Methods

    /// 开始建造
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置（可选）
    /// - Throws: BuildingError
    /// - Returns: 创建的建筑
    @discardableResult
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async throws -> PlayerBuilding {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        guard let template = getTemplate(by: templateId) else {
            throw BuildingError.templateNotFound
        }

        logger.log("开始建造: \(template.name)", type: .info)
        isLoading = true
        defer { isLoading = false }

        // 检查是否可以建造
        let checkResult = canBuildWithInventory(template: template, territoryId: territoryId)

        if checkResult.isMaxReached {
            throw BuildingError.maxBuildingsReached(template.maxPerTerritory)
        }

        if checkResult.isResourceInsufficient {
            throw BuildingError.insufficientResources(checkResult.missingResources)
        }

        // 扣除资源：先从背包扣，不足部分从仓库补
        for (resourceId, requiredAmount) in template.requiredResources {
            var remaining = requiredAmount

            // 1. 先扣背包（按数量降序）
            let backpackItems = InventoryManager.shared.items
                .filter { $0.itemId == resourceId }
                .sorted { $0.quantity > $1.quantity }

            for inventoryItem in backpackItems {
                guard remaining > 0 else { break }
                let deductAmount = min(inventoryItem.quantity, remaining)
                try await InventoryManager.shared.useItem(inventoryId: inventoryItem.id, quantity: deductAmount)
                remaining -= deductAmount
                logger.log("背包扣除: \(resourceId) x\(deductAmount) (剩余需扣: \(remaining))", type: .info)
            }

            // 2. 背包不足，从仓库补充剩余部分
            if remaining > 0 {
                try await WarehouseManager.shared.deductForConstruction(itemId: resourceId, quantity: remaining)
                logger.log("仓库补扣: \(resourceId) x\(remaining)", type: .info)
            }
        }

        // 插入数据库
        let now = Date()

        // 应用建造速度加成（基于订阅档位）
        let buildSpeedMultiplier = SubscriptionManager.shared.buildSpeedMultiplier
        let actualBuildTime = Double(template.buildTimeSeconds) / buildSpeedMultiplier
        let completedAt = now.addingTimeInterval(actualBuildTime)

        logger.log("建造速度: \(String(format: "%.1f", buildSpeedMultiplier))倍，实际耗时: \(Int(actualBuildTime))秒", type: .info)
        let buildingData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "territory_id": .string(territoryId),
            "template_id": .string(templateId),
            "building_name": .string(template.name),
            "status": .string(BuildingStatus.constructing.rawValue),
            "level": .integer(1),
            "location_lat": location != nil ? .double(location!.latitude) : .null,
            "location_lon": location != nil ? .double(location!.longitude) : .null,
            "build_started_at": .string(now.ISO8601Format()),
            "build_completed_at": .string(completedAt.ISO8601Format())
        ]

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .insert(buildingData)
                .select()
                .execute()
                .value

            guard let dbBuilding = response.first,
                  let building = dbBuilding.toPlayerBuilding() else {
                throw BuildingError.saveFailed("无法解析返回的建筑数据")
            }

            // 更新本地数据
            playerBuildings.append(building)

            // 重置领地90天到期计时器
            await TerritoryManager.shared.updateLastActive(territoryId: territoryId)

            logger.log("建筑 \(template.name) 开始建造，预计 \(template.formattedBuildTime) 完成", type: .success)

            return building

        } catch let error as BuildingError {
            throw error
        } catch {
            logger.logError("创建建筑失败", error: error)
            throw BuildingError.saveFailed(error.localizedDescription)
        }
    }

    /// 完成建造
    /// - Parameter buildingId: 建筑 ID
    /// - Throws: BuildingError
    func completeConstruction(buildingId: UUID) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw BuildingError.notAuthenticated
        }

        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        guard building.status == .constructing else {
            throw BuildingError.invalidStatus
        }

        logger.log("完成建造: \(building.buildingName)", type: .info)
        isLoading = true
        defer { isLoading = false }

        let now = Date()

        do {
            try await supabase
                .from("player_buildings")
                .update([
                    "status": BuildingStatus.active.rawValue,
                    "build_completed_at": now.ISO8601Format(),
                    "updated_at": now.ISO8601Format()
                ])
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地数据
            playerBuildings[index].status = .active
            playerBuildings[index].buildCompletedAt = now
            playerBuildings[index].updatedAt = now

            logger.log("建筑 \(building.buildingName) 建造完成", type: .success)

            // 仓库建筑完成后刷新容量
            if ["storage_small", "storage_medium"].contains(building.templateId) {
                Task { await WarehouseManager.shared.refreshItems() }
            }

            // 触发建筑效果
            await applyBuildingEffects(templateId: building.templateId)

        } catch {
            logger.logError("完成建造失败", error: error)
            throw BuildingError.saveFailed(error.localizedDescription)
        }
    }

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Throws: BuildingError
    func upgradeBuilding(buildingId: UUID) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw BuildingError.notAuthenticated
        }

        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        guard building.status == .active else {
            throw BuildingError.invalidStatus
        }

        guard let template = getTemplate(by: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        guard building.level < template.maxLevel else {
            throw BuildingError.maxLevelReached
        }

        // 检查升级所需材料
        let upgradeIndex = building.level - 1  // Lv1→2 uses index 0, Lv2→3 uses index 1, etc.
        if let upgradeResources = template.upgradeResources,
           upgradeIndex < upgradeResources.count {
            let cost = upgradeResources[upgradeIndex]
            let inventory = InventoryManager.shared
            var missing: [String: Int] = [:]
            for (itemId, required) in cost {
                let owned = inventory.items.first(where: { $0.itemId == itemId })?.quantity ?? 0
                if owned < required {
                    missing[itemId] = required - owned
                }
            }
            if !missing.isEmpty {
                throw BuildingError.insufficientResources(missing)
            }
        }

        logger.log("升级建筑: \(building.buildingName) Lv.\(building.level) -> Lv.\(building.level + 1)", type: .info)
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let newLevel = building.level + 1

        do {
            // 扣除升级材料
            if let upgradeResources = template.upgradeResources,
               upgradeIndex < upgradeResources.count {
                let cost = upgradeResources[upgradeIndex]
                for (itemId, amount) in cost {
                    try await InventoryManager.shared.removeItem(itemId: itemId, quantity: amount)
                }
            }

            let updateData: [String: AnyJSON] = [
                "level": .integer(newLevel),
                "updated_at": .string(now.ISO8601Format())
            ]

            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地数据
            playerBuildings[index].level = newLevel
            playerBuildings[index].updatedAt = now

            logger.log("建筑 \(building.buildingName) 升级到 Lv.\(newLevel)", type: .success)

        } catch {
            logger.logError("升级建筑失败", error: error)
            throw BuildingError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Methods

    /// 获取指定领地的建筑
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 建筑列表
    @discardableResult
    func fetchPlayerBuildings(territoryId: String) async throws -> [PlayerBuilding] {
        guard AuthManager.shared.currentUser != nil else {
            throw BuildingError.notAuthenticated
        }

        logger.log("加载领地 \(territoryId) 的建筑...", type: .info)
        isLoading = true
        defer { isLoading = false }

        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw BuildingError.notAuthenticated
        }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("territory_id", value: territoryId)
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let buildings = response.compactMap { $0.toPlayerBuilding() }
            self.playerBuildings = buildings

            logger.log("成功加载 \(buildings.count) 个建筑", type: .success)

            return buildings

        } catch {
            logger.logError("加载建筑失败", error: error)
            throw BuildingError.loadFailed(error.localizedDescription)
        }
    }

    /// 获取当前用户所有建筑
    /// - Returns: 建筑列表
    @discardableResult
    func fetchAllPlayerBuildings() async throws -> [PlayerBuilding] {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw BuildingError.notAuthenticated
        }

        logger.log("加载用户所有建筑...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let buildings = response.compactMap { $0.toPlayerBuilding() }
            self.playerBuildings = buildings

            logger.log("成功加载 \(buildings.count) 个建筑", type: .success)

            return buildings

        } catch {
            logger.logError("加载建筑失败", error: error)
            throw BuildingError.loadFailed(error.localizedDescription)
        }
    }

    /// 刷新建筑列表（根据当前筛选条件）
    func refreshBuildings(territoryId: String? = nil) async {
        do {
            if let territoryId = territoryId {
                _ = try await fetchPlayerBuildings(territoryId: territoryId)
            } else {
                _ = try await fetchAllPlayerBuildings()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Methods

    /// 删除建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Throws: BuildingError
    func deleteBuilding(buildingId: UUID) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw BuildingError.notAuthenticated
        }

        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        logger.log("删除建筑: \(building.buildingName)", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地数据
            playerBuildings.remove(at: index)

            logger.log("建筑 \(building.buildingName) 已删除", type: .success)

        } catch {
            logger.logError("删除建筑失败", error: error)
            throw BuildingError.saveFailed(error.localizedDescription)
        }
    }

    /// 拆除建筑（deleteBuilding 的别名，语义更清晰）
    /// - Parameter buildingId: 建筑 ID
    /// - Throws: BuildingError
    func demolishBuilding(buildingId: UUID) async throws {
        try await deleteBuilding(buildingId: buildingId)
    }

    // MARK: - Helper Methods

    /// 检查并自动完成已到期的建造
    func checkAndCompleteConstructions() async {
        let constructingBuildings = playerBuildings.filter { $0.status == .constructing }

        for building in constructingBuildings {
            guard let template = getTemplate(by: building.templateId) else { continue }

            if building.isConstructionComplete(template: template) {
                do {
                    try await completeConstruction(buildingId: building.id)
                } catch {
                    logger.logError("自动完成建造失败: \(building.buildingName)", error: error)
                }
            }
        }
    }

    /// 获取领地内指定模板的建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }

    /// 检查是否已建有指定建筑（任意领地，状态为active）
    func hasActiveBuilding(templateId: String) -> Bool {
        playerBuildings.contains { $0.templateId == templateId && $0.status == .active }
    }

    // MARK: - Building Effects

    /// 建造完成后触发对应效果
    private func applyBuildingEffects(templateId: String) async {
        switch templateId {
        case "watchtower":
            // 瞭望台：解锁对讲机通讯设备
            await CommunicationManager.shared.unlockDeviceByBuilding(deviceType: "walkie_talkie")
        case "signal_tower":
            // 信号旗台：领地在地图上对其他玩家可见（2km范围）
            TerritoryManager.shared.setTerritoryMapVisible(true)
        case "radio_station":
            // 营地电台：解锁营地通讯设备
            await CommunicationManager.shared.unlockDeviceByBuilding(deviceType: "camp_radio")
        case "lord_command":
            // 领主指挥所：解锁卫星通讯设备
            await CommunicationManager.shared.unlockDeviceByBuilding(deviceType: "satellite")
        default:
            break
        }
        logger.log("建筑效果已应用: \(templateId)", type: .info)
    }

    /// 计算发电机棚对通讯范围的加成倍率
    var generatorRangeBonus: Double {
        hasActiveBuilding(templateId: "generator_shed") ? 1.2 : 1.0
    }

    // MARK: - Building Production

    /// 建筑产出配置（templateId → (itemId, quantity, intervalHours)）
    func productionConfig(for templateId: String) -> (itemId: String, quantity: Int, intervalHours: Double)? {
        switch templateId {
        case "water_barrel": return ("water_bottle", 1, 24)
        default: return nil
        }
    }

    /// 该建筑是否有产出功能
    func hasProduction(_ building: PlayerBuilding) -> Bool {
        productionConfig(for: building.templateId) != nil
    }

    /// 是否可以领取产出
    func canCollect(_ building: PlayerBuilding) -> Bool {
        guard building.status == .active,
              let config = productionConfig(for: building.templateId) else { return false }
        guard let last = building.lastProducedAt else { return true }
        return Date().timeIntervalSince(last) >= config.intervalHours * 3600
    }

    /// 距离下次产出的剩余秒数（nil 表示可立即领取）
    func secondsUntilNextProduction(_ building: PlayerBuilding) -> Double? {
        guard let config = productionConfig(for: building.templateId),
              let last = building.lastProducedAt else { return nil }
        let remaining = config.intervalHours * 3600 - Date().timeIntervalSince(last)
        return remaining > 0 ? remaining : nil
    }

    /// 领取建筑产出
    /// - Parameters:
    ///   - buildingId: 建筑 ID
    ///   - toWarehouse: true = 存入仓库，false = 存入背包
    func collectProduction(buildingId: UUID, toWarehouse: Bool = false) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else { return }
        let building = playerBuildings[index]
        guard let config = productionConfig(for: building.templateId),
              canCollect(building) else { return }

        if toWarehouse {
            // 直接入仓（不经过背包，产出是新生成物品）
            guard WarehouseManager.shared.hasWarehouse else { throw WarehouseError.noWarehouseBuilt }
            guard WarehouseManager.shared.remainingCapacity >= config.quantity else { throw WarehouseError.warehouseFull }
            await WarehouseManager.shared.receiveOutput(itemId: config.itemId, quantity: config.quantity)
        } else {
            // 存入背包
            try await InventoryManager.shared.addItem(
                itemId: config.itemId,
                quantity: config.quantity,
                obtainedFrom: "building_\(building.templateId)"
            )
        }

        // 更新 last_produced_at
        let now = Date()
        try await supabase
            .from("player_buildings")
            .update(["last_produced_at": now.ISO8601Format()])
            .eq("id", value: buildingId.uuidString)
            .execute()

        playerBuildings[index].lastProducedAt = now
        logger.log("领取产出: \(building.buildingName) → \(config.itemId) x\(config.quantity) (\(toWarehouse ? "仓库" : "背包"))", type: .success)
    }
}
