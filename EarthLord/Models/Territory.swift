//
//  Territory.swift
//  EarthLord
//
//  Created on 2025/1/8.
//

import Foundation
import CoreLocation

/// 领地数据模型
/// 用于解析数据库返回的领地数据
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // 可选，数据库允许为空
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let startedAt: String?
    let completedAt: String?
    let createdAt: String?
    let allowTrading: Bool?       // 是否允许他人发现交易（默认 true）
    let lastActiveAt: String?     // 最后活跃时间（用于90天到期检测）
    let broadcastMessage: String? // 领主广播消息（访客搜刮时展示）
    let taxRate: Int?             // 税率（默认10%）
    let buildingCount: Int?       // 已建建筑数量（由触发器维护）

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case allowTrading = "allow_trading"
        case lastActiveAt = "last_active_at"
        case broadcastMessage = "broadcast_message"
        case taxRate = "tax_rate"
        case buildingCount = "building_count"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - 到期相关计算属性

    /// 解析 ISO8601 日期字符串
    private func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }

    /// 从圈地完成时起计算的天数（仅用于90天到期，受 lastActiveAt 重置）
    var daysSinceCompleted: Int? {
        let baseStr = completedAt ?? createdAt
        guard let str = baseStr, let baseDate = parseDate(str) else { return nil }
        // 若玩家有操作记录（建造、领取产出等），以最后活跃时间重置计时器
        let effectiveBase: Date
        if let activeStr = lastActiveAt, let activeDate = parseDate(activeStr), activeDate > baseDate {
            effectiveBase = activeDate
        } else {
            effectiveBase = baseDate
        }
        return Calendar.current.dateComponents([.day], from: effectiveBase, to: Date()).day
    }

    /// 从圈地完成时起计算的天数（固定基准，不受 lastActiveAt 影响，用于30天建设期）
    private var daysSinceCreated: Int? {
        let baseStr = completedAt ?? createdAt
        guard let str = baseStr, let baseDate = parseDate(str) else { return nil }
        return Calendar.current.dateComponents([.day], from: baseDate, to: Date()).day
    }

    /// 距离90天到期还剩几天（nil = 无法计算）
    var daysUntilExpiry: Int? {
        guard let days = daysSinceCompleted else { return nil }
        return max(0, 90 - days)
    }

    /// 是否已超过90天（应被回收）
    var isExpired: Bool {
        guard let days = daysSinceCompleted else { return false }
        return days > 90
    }

    /// 是否处于30天建设期内（以圈地完成时间为基准，不受活跃时间影响）
    var isInBuildPeriod: Bool {
        guard let days = daysSinceCreated else { return false }
        return days <= 30
    }

    /// 距建设截止（30天）还剩几天，已过返回 nil
    var daysUntilBuildDeadline: Int? {
        guard let days = daysSinceCreated else { return nil }
        let remaining = 30 - days
        return remaining > 0 ? remaining : nil
    }

    // MARK: - 到期预警等级

    enum ExpiryWarningLevel {
        case none        // 正常
        case buildNeeded // 在建设期内且无建筑
        case caution     // 距到期 ≤ 14天
        case danger      // 距到期 ≤ 7天
        case expired     // 已到期
    }

    /// 计算到期预警等级（需传入当前建筑数量）
    func expiryWarningLevel(buildingCount: Int) -> ExpiryWarningLevel {
        if isExpired { return .expired }
        if let remaining = daysUntilExpiry {
            if remaining <= 7 { return .danger }
            if remaining <= 14 { return .caution }
        }
        if isInBuildPeriod && buildingCount == 0 { return .buildNeeded }
        return .none
    }
}
