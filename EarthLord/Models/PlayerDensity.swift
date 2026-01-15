//
//  PlayerDensity.swift
//  EarthLord
//
//  玩家密度等级模型 - 用于根据附近玩家数量动态调整POI显示
//

import Foundation

/// 玩家密度等级
enum PlayerDensityLevel: String, CaseIterable {
    case loner = "独行者"      // 0人
    case low = "低密度"        // 1-5人
    case medium = "中密度"     // 6-20人
    case high = "高密度"       // 20人+

    /// 根据附近玩家数量确定密度等级
    static func from(count: Int) -> PlayerDensityLevel {
        switch count {
        case 0:
            return .loner
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 该密度等级对应的POI显示数量范围
    var poiCountRange: ClosedRange<Int> {
        switch self {
        case .loner:
            return 1...1
        case .low:
            return 2...3
        case .medium:
            return 4...6
        case .high:
            return 7...Int.max  // 显示全部
        }
    }

    /// 推荐的POI数量 (-1 表示不限制)
    var recommendedPOICount: Int {
        switch self {
        case .loner:
            return 1
        case .low:
            return 3
        case .medium:
            return 5
        case .high:
            return -1  // -1 表示不限制
        }
    }

    /// 等级描述
    var description: String {
        switch self {
        case .loner:
            return "附近没有其他幸存者，物资充足但要小心..."
        case .low:
            return "附近有少量幸存者，竞争不激烈"
        case .medium:
            return "附近有一些幸存者，物资竞争中等"
        case .high:
            return "附近幸存者众多，物资竞争激烈！"
        }
    }

    /// 等级图标
    var icon: String {
        switch self {
        case .loner:
            return "person"
        case .low:
            return "person.2"
        case .medium:
            return "person.3"
        case .high:
            return "person.3.fill"
        }
    }
}

/// 玩家密度查询结果
struct PlayerDensityResult {
    /// 附近玩家数量
    let nearbyCount: Int

    /// 密度等级
    let densityLevel: PlayerDensityLevel

    /// 查询时间
    let queriedAt: Date

    /// 查询中心纬度
    let centerLatitude: Double

    /// 查询中心经度
    let centerLongitude: Double

    init(count: Int, latitude: Double, longitude: Double) {
        self.nearbyCount = count
        self.densityLevel = PlayerDensityLevel.from(count: count)
        self.queriedAt = Date()
        self.centerLatitude = latitude
        self.centerLongitude = longitude
    }
}

#if DEBUG
extension PlayerDensityResult {
    /// 测试用模拟数据
    static let mockLoner = PlayerDensityResult(count: 0, latitude: 31.23, longitude: 121.47)
    static let mockLow = PlayerDensityResult(count: 3, latitude: 31.23, longitude: 121.47)
    static let mockMedium = PlayerDensityResult(count: 12, latitude: 31.23, longitude: 121.47)
    static let mockHigh = PlayerDensityResult(count: 30, latitude: 31.23, longitude: 121.47)
}
#endif
