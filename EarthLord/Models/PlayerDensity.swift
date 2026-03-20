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

    /// 稀有物品概率修正（影响搜刮物品质量）
    /// 正值=提升稀有率（无人区废墟物资丰富），负值=降低稀有率（热门区物资匮乏）
    var rareProbabilityModifier: Double {
        switch self {
        case .loner:  return  0.30  // +30%：无人涉足的废墟，物资保存完好
        case .low:    return  0.00  // 基准
        case .medium: return -0.15  // -15%：经常有人搜刮
        case .high:   return -0.30  // -30%：热门区域，几乎被翻遍
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
