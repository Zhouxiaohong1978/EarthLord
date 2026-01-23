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

    /// 使用 InventoryManager 的背包数据检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    /// - Returns: 建造检查结果
    func canBuildWithInventory(
        template: BuildingTemplate,
        territoryId: String
    ) -> CanBuildResult {
        // 从 InventoryManager 获取玩家资源
        let inventory = InventoryManager.shared.items
        var playerResources: [String: Int] = [:]

        for item in inventory {
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

        // 扣除资源
        for (resourceId, requiredAmount) in template.requiredResources {
            if let inventoryItem = InventoryManager.shared.items.first(where: { $0.itemId == resourceId }) {
                try await InventoryManager.shared.useItem(inventoryId: inventoryItem.id, quantity: requiredAmount)
                logger.log("扣除资源: \(resourceId) x\(requiredAmount)", type: .info)
            }
        }

        // 插入数据库
        let now = Date()
        let completedAt = now.addingTimeInterval(Double(template.buildTimeSeconds))
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

        logger.log("升级建筑: \(building.buildingName) Lv.\(building.level) -> Lv.\(building.level + 1)", type: .info)
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let newLevel = building.level + 1

        do {
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
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        logger.log("加载领地 \(territoryId) 的建筑...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
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

    /// 获取用户所有建筑
    /// - Returns: 建筑列表
    @discardableResult
    func fetchAllPlayerBuildings() async throws -> [PlayerBuilding] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        logger.log("加载用户所有建筑...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
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
    /// - Parameters:
    ///   - templateId: 模板 ID
    ///   - territoryId: 领地 ID
    /// - Returns: 建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }
}
