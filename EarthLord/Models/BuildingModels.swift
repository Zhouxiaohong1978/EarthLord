//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型
//  包含：建筑分类、状态、模板、玩家建筑、错误类型
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - BuildingCategory 建筑分类

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"           // 生存
    case storage = "storage"             // 储存
    case production = "production"       // 生产
    case energy = "energy"               // 能源
    case communication = "communication" // 通讯
    case defense = "defense"             // 防御
    case glory = "glory"                 // 荣耀

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .survival:      return String(localized: "生存")
        case .storage:       return String(localized: "储存")
        case .production:    return String(localized: "生产")
        case .energy:        return String(localized: "能源")
        case .communication: return String(localized: "通讯")
        case .defense:       return String(localized: "防御")
        case .glory:         return String(localized: "荣耀")
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .survival:      return "flame.fill"
        case .storage:       return "archivebox.fill"
        case .production:    return "hammer.fill"
        case .energy:        return "bolt.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .defense:       return "shield.fill"
        case .glory:         return "crown.fill"
        }
    }

    /// 分类颜色
    var color: Color {
        switch self {
        case .survival:      return ApocalypseTheme.primary
        case .storage:       return ApocalypseTheme.info
        case .production:    return ApocalypseTheme.success
        case .energy:        return ApocalypseTheme.warning
        case .communication: return ApocalypseTheme.danger
        case .defense:       return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .glory:         return Color(red: 1.0, green: 0.85, blue: 0.0)
        }
    }
}

// MARK: - BuildingStatus 建筑状态

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case upgrading = "upgrading"        // 升级中
    case active = "active"              // 运行中
    case inactive = "inactive"          // 已停用
    case damaged = "damaged"            // 已损坏

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .constructing:
            return String(localized: "建造中")
        case .upgrading:
            return String(localized: "升级中")
        case .active:
            return String(localized: "运行中")
        case .inactive:
            return String(localized: "已停用")
        case .damaged:
            return String(localized: "已损坏")
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing:
            return .orange
        case .upgrading:
            return ApocalypseTheme.info
        case .active:
            return ApocalypseTheme.success
        case .inactive:
            return .gray
        case .damaged:
            return ApocalypseTheme.danger
        }
    }

    /// 状态图标
    var icon: String {
        switch self {
        case .constructing:
            return "hammer.fill"
        case .upgrading:
            return "arrow.up.circle.fill"
        case .active:
            return "checkmark.circle.fill"
        case .inactive:
            return "pause.circle.fill"
        case .damaged:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - BuildingTemplate 建筑模板

/// 建筑模板结构体（从 JSON 解码）
struct BuildingTemplate: Identifiable, Codable {
    let id: String
    let templateId: String
    let name: String
    let nameEn: String?
    let category: BuildingCategory
    let tier: Int
    let description: String
    let descriptionEn: String?
    let icon: String
    let mapIconSize: Int?
    let requiredResources: [String: Int]
    var upgradeResources: [[String: Int]]? = nil
    var prerequisites: [String]? = nil
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int
    var defaultPublicVisible: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case nameEn = "name_en"
        case category
        case tier
        case description
        case descriptionEn = "description_en"
        case icon
        case mapIconSize = "map_icon_size"
        case requiredResources = "required_resources"
        case upgradeResources = "upgrade_resources"
        case prerequisites
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
        case defaultPublicVisible = "defaultPublicVisible"
    }

    /// 根据当前语言返回本地化名称
    var localizedName: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        return lang.hasPrefix("en") ? (nameEn ?? name) : name
    }

    /// 根据当前语言返回本地化描述
    var localizedDescription: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        return lang.hasPrefix("en") ? (descriptionEn ?? description) : description
    }

    /// 获取格式化的建造时间（传入订阅加速倍率）
    func formattedBuildTime(multiplier: Double = 1.0) -> String {
        let actualSeconds = Int(Double(buildTimeSeconds) / multiplier)
        let minutes = actualSeconds / 60
        let seconds = actualSeconds % 60
        if minutes > 0 && seconds > 0 {
            return String(format: String(localized: "%d分%d秒"), minutes, seconds)
        } else if minutes > 0 {
            return String(format: String(localized: "%d分钟"), minutes)
        } else {
            return String(format: String(localized: "%d秒"), seconds)
        }
    }

    /// 加速标注文字，如 "×2 加速"
    func buildSpeedLabel(multiplier: Double) -> String {
        let boost = String(localized: "加速")
        if multiplier == Double(Int(multiplier)) {
            return "×\(Int(multiplier)) \(boost)"
        }
        return "×\(String(format: "%.1f", multiplier)) \(boost)"
    }

    /// 获取所需资源的显示文本
    var resourcesDisplayText: String {
        requiredResources.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
    }

    /// 仓库容量（仅 storage 类建筑有效，按等级返回）
    func storageCapacity(at level: Int) -> Int {
        let clampedLevel = max(1, min(level, maxLevel))
        switch id {
        case "storage_small":
            return [500, 800, 1200][clampedLevel - 1]
        case "storage_medium":
            return [1500, 2000, 3000][clampedLevel - 1]
        default:
            return 0
        }
    }

    /// 是否是仓库建筑
    var isStorage: Bool { category == .storage }
}

/// 建筑模板容器（用于 JSON 解码）
struct BuildingTemplateContainer: Codable {
    let templates: [BuildingTemplate]
}

// MARK: - PlayerBuilding 玩家建筑

/// 玩家建筑结构体（对应数据库 player_buildings 表）
struct PlayerBuilding: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    var mapDisplaySize: Int?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date
    var lastProducedAt: Date?
    var durability: Int = 100
    var lastMaintainedAt: Date?
    var durabilityZeroAt: Date?
    var showToOthers: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case mapDisplaySize = "map_display_size"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastProducedAt = "last_produced_at"
        case durability
        case lastMaintainedAt = "last_maintained_at"
        case durabilityZeroAt = "durability_zero_at"
        case showToOthers = "show_to_others"
    }

    /// 检查建造是否已完成（优先用 build_completed_at，兼容加速道具）
    func isConstructionComplete(template: BuildingTemplate) -> Bool {
        if let completedAt = buildCompletedAt {
            return Date() >= completedAt
        }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return elapsed >= Double(template.buildTimeSeconds)
    }

    /// 获取建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate) -> Int {
        if let completedAt = buildCompletedAt {
            return max(0, Int(completedAt.timeIntervalSinceNow))
        }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return max(0, Int(Double(template.buildTimeSeconds) - elapsed))
    }

    /// 获取建造进度（0.0 - 1.0）
    func buildProgress(template: BuildingTemplate) -> Double {
        if let completedAt = buildCompletedAt {
            let total = completedAt.timeIntervalSince(buildStartedAt)
            let elapsed = Date().timeIntervalSince(buildStartedAt)
            return min(1.0, max(0.0, elapsed / total))
        }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(1.0, max(0.0, elapsed / Double(template.buildTimeSeconds)))
    }

    // MARK: - 便捷计算属性

    /// 坐标便捷属性
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 建造进度（0.0 ~ 1.0）- 基于 buildCompletedAt
    var buildProgress: Double {
        guard status == .constructing || status == .upgrading,
              let completedAt = buildCompletedAt else { return 0 }

        let total = completedAt.timeIntervalSince(buildStartedAt)
        guard total > 0 else { return 1.0 }

        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(1.0, max(0, elapsed / total))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard status == .constructing || status == .upgrading,
              let completedAt = buildCompletedAt else { return "" }

        let remaining = completedAt.timeIntervalSince(Date())
        guard remaining > 0 else { return String(localized: "即将完成") }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - PlayerBuildingDB 数据库模型

/// 玩家建筑数据库模型（用于 Supabase）
struct PlayerBuildingDB: Codable {
    let id: String?
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let mapDisplaySize: Int?
    let buildStartedAt: String
    let buildCompletedAt: String?
    let createdAt: String?
    let updatedAt: String?
    let lastProducedAt: String?
    let durability: Int?
    let lastMaintainedAt: String?
    let durabilityZeroAt: String?
    let showToOthers: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case mapDisplaySize = "map_display_size"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastProducedAt = "last_produced_at"
        case durability
        case lastMaintainedAt = "last_maintained_at"
        case durabilityZeroAt = "durability_zero_at"
        case showToOthers = "show_to_others"
    }

    /// 转换为 PlayerBuilding
    func toPlayerBuilding() -> PlayerBuilding? {
        guard let idString = id,
              let id = UUID(uuidString: idString),
              let userId = UUID(uuidString: userId),
              let status = BuildingStatus(rawValue: status) else {
            return nil
        }

        let fmtFull = ISO8601DateFormatter()
        fmtFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmtBasic = ISO8601DateFormatter()
        fmtBasic.formatOptions = [.withInternetDateTime]

        func parseDate(_ s: String) -> Date? {
            fmtFull.date(from: s) ?? fmtBasic.date(from: s)
        }

        let buildStarted = parseDate(buildStartedAt) ?? Date()
        let buildCompleted = buildCompletedAt.flatMap { parseDate($0) }
        let created = createdAt.flatMap { parseDate($0) } ?? Date()
        let updated = updatedAt.flatMap { parseDate($0) } ?? Date()
        let lastProduced = lastProducedAt.flatMap { parseDate($0) }
        let lastMaintained = lastMaintainedAt.flatMap { parseDate($0) }
        let durabilityZero = durabilityZeroAt.flatMap { parseDate($0) }

        return PlayerBuilding(
            id: id,
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: buildingName,
            status: status,
            level: level,
            locationLat: locationLat,
            locationLon: locationLon,
            mapDisplaySize: mapDisplaySize,
            buildStartedAt: buildStarted,
            buildCompletedAt: buildCompleted,
            createdAt: created,
            updatedAt: updated,
            lastProducedAt: lastProduced,
            durability: durability ?? 100,
            lastMaintainedAt: lastMaintained,
            durabilityZeroAt: durabilityZero,
            showToOthers: showToOthers ?? false
        )
    }
}

// MARK: - BuildingError 错误类型

/// 建筑操作错误类型
enum BuildingError: LocalizedError {
    case notAuthenticated
    case insufficientResources([String: Int])
    case maxBuildingsReached(Int)
    case templateNotFound
    case invalidStatus
    case maxLevelReached
    case buildingNotFound
    case saveFailed(String)
    case loadFailed(String)
    case prerequisiteNotMet(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "用户未登录")
        case .insufficientResources(let missing):
            let resourceList = missing.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            return String(format: String(localized: "资源不足，还需要: %@"), resourceList)
        case .maxBuildingsReached(let max):
            return String(format: String(localized: "该建筑已达到领地上限 (%d)"), max)
        case .templateNotFound:
            return String(localized: "建筑模板不存在")
        case .invalidStatus:
            return String(localized: "建筑状态无效")
        case .maxLevelReached:
            return String(localized: "建筑已达到最高等级")
        case .buildingNotFound:
            return String(localized: "建筑不存在")
        case .saveFailed(let message):
            return String(format: String(localized: "保存失败: %@"), message)
        case .loadFailed(let message):
            return String(format: String(localized: "加载失败: %@"), message)
        case .prerequisiteNotMet(let buildingId):
            return String(format: String(localized: "需要先建造前置建筑: %@"), buildingId)
        }
    }
}

// MARK: - CanBuildResult 建造检查结果

/// 建造检查结果
struct CanBuildResult {
    let canBuild: Bool
    let missingResources: [String: Int]
    let currentCount: Int
    let maxCount: Int
    let unmetPrerequisite: String?

    init(canBuild: Bool, missingResources: [String: Int], currentCount: Int, maxCount: Int, unmetPrerequisite: String? = nil) {
        self.canBuild = canBuild
        self.missingResources = missingResources
        self.currentCount = currentCount
        self.maxCount = maxCount
        self.unmetPrerequisite = unmetPrerequisite
    }

    /// 是否因为资源不足而无法建造
    var isResourceInsufficient: Bool {
        return !missingResources.isEmpty
    }

    /// 是否因为数量限制而无法建造
    var isMaxReached: Bool {
        return currentCount >= maxCount
    }

    /// 是否因为前置建筑未满足而无法建造
    var isPrerequisiteNotMet: Bool {
        return unmetPrerequisite != nil
    }

    /// 成功结果
    static func success(currentCount: Int, maxCount: Int) -> CanBuildResult {
        return CanBuildResult(
            canBuild: true,
            missingResources: [:],
            currentCount: currentCount,
            maxCount: maxCount
        )
    }

    /// 资源不足结果
    static func insufficientResources(_ missing: [String: Int], currentCount: Int, maxCount: Int) -> CanBuildResult {
        return CanBuildResult(
            canBuild: false,
            missingResources: missing,
            currentCount: currentCount,
            maxCount: maxCount
        )
    }

    /// 前置建筑未满足结果
    static func prerequisiteNotMet(_ prereqId: String, currentCount: Int, maxCount: Int) -> CanBuildResult {
        return CanBuildResult(
            canBuild: false,
            missingResources: [:],
            currentCount: currentCount,
            maxCount: maxCount,
            unmetPrerequisite: prereqId
        )
    }

    /// 达到上限结果
    static func maxReached(currentCount: Int, maxCount: Int) -> CanBuildResult {
        return CanBuildResult(
            canBuild: false,
            missingResources: [:],
            currentCount: currentCount,
            maxCount: maxCount
        )
    }
}
