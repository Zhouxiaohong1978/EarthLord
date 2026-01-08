//
//  CollisionModels.swift
//  EarthLord
//
//  碰撞检测相关的数据模型
//

import Foundation

// MARK: - 预警级别

/// 预警级别枚举
/// 用于表示当前位置与他人领地的接近程度
enum WarningLevel: Int {
    case safe = 0       // 安全（>100m）
    case caution = 1    // 注意（50-100m）- 黄色横幅
    case warning = 2    // 警告（25-50m）- 橙色横幅
    case danger = 3     // 危险（<25m）- 红色横幅
    case violation = 4  // 违规（已碰撞）- 红色横幅 + 停止圈地

    var description: String {
        switch self {
        case .safe: return "安全"
        case .caution: return "注意"
        case .warning: return "警告"
        case .danger: return "危险"
        case .violation: return "违规"
        }
    }
}

// MARK: - 碰撞类型

/// 碰撞类型枚举
/// 用于区分不同的碰撞情况
enum CollisionType {
    case pointInTerritory       // 点在他人领地内
    case pathCrossTerritory     // 路径穿越他人领地边界
    case selfIntersection       // 自相交（Day 17 已有）
}

// MARK: - 碰撞检测结果

/// 碰撞检测结果结构体
/// 包含检测结果的所有相关信息
struct CollisionResult {
    let hasCollision: Bool          // 是否碰撞
    let collisionType: CollisionType?   // 碰撞类型
    let message: String?            // 提示消息
    let closestDistance: Double?    // 距离最近领地的距离（米）
    let warningLevel: WarningLevel  // 预警级别

    // 便捷构造器：安全状态
    static var safe: CollisionResult {
        CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: nil,
            closestDistance: nil,
            warningLevel: .safe
        )
    }
}
