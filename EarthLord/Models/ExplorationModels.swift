//
//  ExplorationModels.swift
//  EarthLord
//
//  探索功能相关数据模型
//

import Foundation
import CoreLocation

// MARK: - 探索状态枚举

/// 探索状态
enum ExplorationState: Equatable {
    /// 空闲状态
    case idle
    /// 探索中
    case exploring
    /// 超速警告（包含剩余秒数）
    case overSpeedWarning(secondsRemaining: Int)
    /// 探索完成
    case completed(result: ExplorationSessionResult)
    /// 探索失败
    case failed(reason: ExplorationFailureReason)

    static func == (lhs: ExplorationState, rhs: ExplorationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.exploring, .exploring):
            return true
        case (.overSpeedWarning(let l), .overSpeedWarning(let r)):
            return l == r
        case (.completed, .completed):
            return true
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - 探索失败原因

/// 探索失败原因枚举
enum ExplorationFailureReason: Equatable {
    /// 超速
    case overSpeed
    /// 用户取消
    case cancelled
    /// 定位错误
    case locationError(String)

    static func == (lhs: ExplorationFailureReason, rhs: ExplorationFailureReason) -> Bool {
        switch (lhs, rhs) {
        case (.overSpeed, .overSpeed):
            return true
        case (.cancelled, .cancelled):
            return true
        case (.locationError(let l), .locationError(let r)):
            return l == r
        default:
            return false
        }
    }

    /// 获取失败原因描述
    var description: String {
        switch self {
        case .overSpeed:
            return "移动速度过快，探索已终止"
        case .cancelled:
            return "探索已取消"
        case .locationError(let message):
            return "定位错误：\(message)"
        }
    }
}

// MARK: - 奖励等级

/// 奖励等级枚举
enum RewardTier: String, Codable {
    /// 无奖励（0-200米）
    case none = "none"
    /// 铜级（200-500米）
    case bronze = "bronze"
    /// 银级（500-1000米）
    case silver = "silver"
    /// 金级（1000-2000米）
    case gold = "gold"
    /// 钻石级（2000米以上）
    case diamond = "diamond"

    /// 获取等级显示名称
    var displayName: String {
        switch self {
        case .none:
            return "无奖励"
        case .bronze:
            return "铜级"
        case .silver:
            return "银级"
        case .gold:
            return "金级"
        case .diamond:
            return "钻石级"
        }
    }

    /// 获取等级图标
    var icon: String {
        switch self {
        case .none:
            return "minus.circle"
        case .bronze:
            return "medal"
        case .silver:
            return "medal.fill"
        case .gold:
            return "star.fill"
        case .diamond:
            return "sparkles"
        }
    }

    /// 获取物品数量
    var itemCount: Int {
        switch self {
        case .none:
            return 0
        case .bronze:
            return 1
        case .silver:
            return 2
        case .gold:
            return 3
        case .diamond:
            return 5
        }
    }

    /// 获取普通物品概率
    var commonProbability: Double {
        switch self {
        case .none:
            return 0
        case .bronze:
            return 0.90
        case .silver:
            return 0.70
        case .gold:
            return 0.50
        case .diamond:
            return 0.30
        }
    }

    /// 获取稀有物品概率
    var rareProbability: Double {
        switch self {
        case .none:
            return 0
        case .bronze:
            return 0.10
        case .silver:
            return 0.25
        case .gold:
            return 0.35
        case .diamond:
            return 0.40
        }
    }

    /// 获取史诗物品概率
    var epicProbability: Double {
        switch self {
        case .none:
            return 0
        case .bronze:
            return 0
        case .silver:
            return 0.05
        case .gold:
            return 0.15
        case .diamond:
            return 0.30
        }
    }

    /// 根据距离计算奖励等级
    static func from(distance: Double) -> RewardTier {
        switch distance {
        case 0..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }
}

// MARK: - 探索会话结果

/// 探索会话结果
struct ExplorationSessionResult: Identifiable, Equatable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let distanceWalked: Double  // 米
    let durationSeconds: Int
    let status: String
    let rewardTier: RewardTier
    let obtainedItems: [ObtainedItem]
    let path: [(coordinate: CLLocationCoordinate2D, timestamp: Date)]
    let maxSpeed: Double  // km/h

    static func == (lhs: ExplorationSessionResult, rhs: ExplorationSessionResult) -> Bool {
        return lhs.id == rhs.id
    }

    /// 获取格式化的距离字符串
    var formattedDistance: String {
        if distanceWalked >= 1000 {
            return String(format: "%.2f 公里", distanceWalked / 1000)
        } else {
            return String(format: "%.0f 米", distanceWalked)
        }
    }

    /// 获取格式化的时长字符串
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%d小时%d分%d秒", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d分%d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
}

// MARK: - 获得的物品

/// 获得的物品（用于探索奖励）
struct ObtainedItem: Identifiable, Equatable {
    let id: UUID
    let itemId: String
    let quantity: Int
    let quality: ItemQuality?

    init(itemId: String, quantity: Int, quality: ItemQuality? = nil) {
        self.id = UUID()
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
    }

    static func == (lhs: ObtainedItem, rhs: ObtainedItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Supabase 数据模型

/// 探索会话数据库模型（用于 Supabase）
struct ExplorationSessionDB: Codable {
    let id: String?
    let userId: String
    let startedAt: String
    let endedAt: String
    let distanceWalked: Double
    let durationSeconds: Int
    let status: String
    let rewardTier: String?
    let path: [[String: Any]]?
    let maxSpeed: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case distanceWalked = "distance_walked"
        case durationSeconds = "duration_seconds"
        case status
        case rewardTier = "reward_tier"
        case path
        case maxSpeed = "max_speed"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        startedAt = try container.decode(String.self, forKey: .startedAt)
        endedAt = try container.decode(String.self, forKey: .endedAt)
        distanceWalked = try container.decode(Double.self, forKey: .distanceWalked)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        status = try container.decode(String.self, forKey: .status)
        rewardTier = try container.decodeIfPresent(String.self, forKey: .rewardTier)
        path = nil  // JSONB 需要特殊处理
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(distanceWalked, forKey: .distanceWalked)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(rewardTier, forKey: .rewardTier)
        try container.encodeIfPresent(maxSpeed, forKey: .maxSpeed)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

/// 背包物品数据库模型（用于 Supabase）
struct InventoryItemDB: Codable {
    let id: String?
    let userId: String
    let itemId: String
    let quantity: Int
    let quality: String?
    let obtainedFrom: String?
    let explorationSessionId: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedFrom = "obtained_from"
        case explorationSessionId = "exploration_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 路径点模型

/// 路径点（用于记录探索轨迹）
struct PathPoint: Codable {
    let lat: Double
    let lon: Double
    let timestamp: String

    init(coordinate: CLLocationCoordinate2D, date: Date) {
        self.lat = coordinate.latitude
        self.lon = coordinate.longitude
        self.timestamp = ISO8601DateFormatter().string(from: date)
    }
}
