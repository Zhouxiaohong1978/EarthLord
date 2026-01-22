//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型
//  包含：建筑分类、状态、模板、玩家建筑、错误类型
//

import Foundation
import SwiftUI

// MARK: - BuildingCategory 建筑分类

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .survival:
            return String(localized: "生存")
        case .storage:
            return String(localized: "储存")
        case .production:
            return String(localized: "生产")
        case .energy:
            return String(localized: "能源")
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .survival:
            return "flame.fill"
        case .storage:
            return "archivebox.fill"
        case .production:
            return "hammer.fill"
        case .energy:
            return "bolt.fill"
        }
    }

    /// 分类颜色
    var color: Color {
        switch self {
        case .survival:
            return ApocalypseTheme.primary
        case .storage:
            return ApocalypseTheme.info
        case .production:
            return ApocalypseTheme.success
        case .energy:
            return ApocalypseTheme.warning
        }
    }
}

// MARK: - BuildingStatus 建筑状态

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .constructing:
            return String(localized: "建造中")
        case .active:
            return String(localized: "运行中")
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing:
            return ApocalypseTheme.info
        case .active:
            return ApocalypseTheme.success
        }
    }

    /// 状态图标
    var icon: String {
        switch self {
        case .constructing:
            return "hammer.fill"
        case .active:
            return "checkmark.circle.fill"
        }
    }
}

// MARK: - BuildingTemplate 建筑模板

/// 建筑模板结构体（从 JSON 解码）
struct BuildingTemplate: Identifiable, Codable {
    let id: String
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }

    /// 获取格式化的建造时间
    var formattedBuildTime: String {
        let minutes = buildTimeSeconds / 60
        let seconds = buildTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 获取所需资源的显示文本
    var resourcesDisplayText: String {
        requiredResources.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
    }
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
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date

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
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 检查建造是否已完成（根据时间）
    func isConstructionComplete(template: BuildingTemplate) -> Bool {
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return elapsed >= Double(template.buildTimeSeconds)
    }

    /// 获取建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate) -> Int {
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let remaining = Double(template.buildTimeSeconds) - elapsed
        return max(0, Int(remaining))
    }

    /// 获取建造进度（0.0 - 1.0）
    func buildProgress(template: BuildingTemplate) -> Double {
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let progress = elapsed / Double(template.buildTimeSeconds)
        return min(1.0, max(0.0, progress))
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
    let buildStartedAt: String
    let buildCompletedAt: String?
    let createdAt: String?
    let updatedAt: String?

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
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为 PlayerBuilding
    func toPlayerBuilding() -> PlayerBuilding? {
        guard let idString = id,
              let id = UUID(uuidString: idString),
              let userId = UUID(uuidString: userId),
              let status = BuildingStatus(rawValue: status) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let buildStarted = dateFormatter.date(from: buildStartedAt) ?? Date()
        let buildCompleted = buildCompletedAt.flatMap { dateFormatter.date(from: $0) }
        let created = createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updated = updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()

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
            buildStartedAt: buildStarted,
            buildCompletedAt: buildCompleted,
            createdAt: created,
            updatedAt: updated
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

    /// 是否因为资源不足而无法建造
    var isResourceInsufficient: Bool {
        return !missingResources.isEmpty
    }

    /// 是否因为数量限制而无法建造
    var isMaxReached: Bool {
        return currentCount >= maxCount
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
