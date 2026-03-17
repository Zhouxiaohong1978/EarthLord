//
//  AchievementModels.swift
//  EarthLord
//
//  成就系统数据模型 - 5章节叙事式成就

import Foundation
import SwiftUI

// MARK: - Chapter

enum AchievementChapter: Int, CaseIterable, Identifiable {
    case zeroDay = 0
    case sprout = 1
    case breakthrough = 2
    case pioneer = 3
    case legend = 4

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .zeroDay:      return "零日 · 幸存"
        case .sprout:       return "新芽 · 萌发"
        case .breakthrough: return "破土 · 重生"
        case .pioneer:      return "开拓 · 家园"
        case .legend:       return "缔造 · 新世界"
        }
    }

    var shortTitleKey: String {
        switch self {
        case .zeroDay:      return "零日"
        case .sprout:       return "新芽"
        case .breakthrough: return "破土"
        case .pioneer:      return "家园"
        case .legend:       return "缔造"
        }
    }

    var subtitleKey: String {
        switch self {
        case .zeroDay:      return "你从废墟中醒来"
        case .sprout:       return "第一株希望开始生长"
        case .breakthrough: return "在废土上找到了立足之地"
        case .pioneer:      return "你的家园正在成形"
        case .legend:       return "新世界的缔造者"
        }
    }

    var color: Color {
        switch self {
        case .zeroDay:      return .gray
        case .sprout:       return ApocalypseTheme.success
        case .breakthrough: return ApocalypseTheme.warning
        case .pioneer:      return ApocalypseTheme.primary
        case .legend:       return ApocalypseTheme.info
        }
    }

    var icon: String {
        switch self {
        case .zeroDay:      return "person.crop.circle.fill"
        case .sprout:       return "leaf.fill"
        case .breakthrough: return "sunrise.fill"
        case .pioneer:      return "house.fill"
        case .legend:       return "crown.fill"
        }
    }
}

// MARK: - Condition

enum AchievementCondition {
    case firstLogin
    case explorationCount(Int)
    case totalDistance(Double)       // meters
    case territoryCount(Int)
    case totalTerritoryArea(Double)  // m²
    case buildingCount(Int)
}

// MARK: - Definition

struct AchievementDefinition: Identifiable {
    let id: String
    let chapter: AchievementChapter
    let icon: String
    let titleKey: String
    let descriptionKey: String

    let condition: AchievementCondition

    /// 图标颜色 - 按成就类型区分
    var iconColor: Color {
        switch condition {
        case .firstLogin:            return ApocalypseTheme.info
        case .explorationCount:      return ApocalypseTheme.warning
        case .totalDistance:         return ApocalypseTheme.info
        case .territoryCount,
             .totalTerritoryArea:    return ApocalypseTheme.success
        case .buildingCount:         return ApocalypseTheme.primary
        }
    }

    var targetValue: Double {
        switch condition {
        case .firstLogin:                return 1
        case .explorationCount(let n):   return Double(n)
        case .totalDistance(let d):      return d
        case .territoryCount(let n):     return Double(n)
        case .totalTerritoryArea(let a): return a
        case .buildingCount(let n):      return Double(n)
        }
    }
}

// MARK: - Catalog

extension AchievementDefinition {
    static let catalog: [AchievementDefinition] = [

        // MARK: Chapter 0: 零日·幸存
        AchievementDefinition(id: "first_login",       chapter: .zeroDay, icon: "person.fill.checkmark", titleKey: "幸存者诞生", descriptionKey: "踏入末日世界",     condition: .firstLogin),
        AchievementDefinition(id: "first_exploration", chapter: .zeroDay, icon: "figure.walk",           titleKey: "迈出第一步", descriptionKey: "完成第一次探索",    condition: .explorationCount(1)),
        AchievementDefinition(id: "first_territory",   chapter: .zeroDay, icon: "map.fill",              titleKey: "占领一角",   descriptionKey: "圈定第一块领地",    condition: .territoryCount(1)),
        AchievementDefinition(id: "first_building",    chapter: .zeroDay, icon: "building.2.fill",       titleKey: "搭建庇护所", descriptionKey: "建造第一座建筑",    condition: .buildingCount(1)),
        AchievementDefinition(id: "exploration_5",     chapter: .zeroDay, icon: "binoculars.fill",       titleKey: "初探废土",   descriptionKey: "累计完成 5 次探索", condition: .explorationCount(5)),

        // MARK: Chapter 1: 新芽·萌发
        AchievementDefinition(id: "distance_10km",  chapter: .sprout, icon: "figure.walk.circle.fill",  titleKey: "脚踏实地",  descriptionKey: "累计探索 10 公里",      condition: .totalDistance(10_000)),
        AchievementDefinition(id: "territory_10k",  chapter: .sprout, icon: "square.fill",              titleKey: "扩大领地",  descriptionKey: "领地总面积 10,000 m²",  condition: .totalTerritoryArea(10_000)),
        AchievementDefinition(id: "buildings_5",    chapter: .sprout, icon: "building.2",               titleKey: "小有规模",  descriptionKey: "建造 5 座建筑",         condition: .buildingCount(5)),
        AchievementDefinition(id: "exploration_20", chapter: .sprout, icon: "calendar.badge.checkmark", titleKey: "废土探险家", descriptionKey: "累计完成 20 次探索",    condition: .explorationCount(20)),

        // MARK: Chapter 2: 破土·重生
        AchievementDefinition(id: "distance_100km",  chapter: .breakthrough, icon: "map.circle.fill",       titleKey: "长途跋涉",   descriptionKey: "累计探索 100 公里",       condition: .totalDistance(100_000)),
        AchievementDefinition(id: "territory_100k",  chapter: .breakthrough, icon: "map.fill",              titleKey: "领地主人",   descriptionKey: "领地总面积 100,000 m²",  condition: .totalTerritoryArea(100_000)),
        AchievementDefinition(id: "buildings_20",    chapter: .breakthrough, icon: "building.columns.fill", titleKey: "营地建设者", descriptionKey: "建造 20 座建筑",         condition: .buildingCount(20)),
        AchievementDefinition(id: "exploration_50",  chapter: .breakthrough, icon: "shield.fill",           titleKey: "老兵出征",   descriptionKey: "累计完成 50 次探索",     condition: .explorationCount(50)),

        // MARK: Chapter 3: 开拓·家园
        AchievementDefinition(id: "distance_500km",  chapter: .pioneer, icon: "figure.hiking",               titleKey: "千里之行",   descriptionKey: "累计探索 500 公里",      condition: .totalDistance(500_000)),
        AchievementDefinition(id: "territory_1km2",  chapter: .pioneer, icon: "globe.asia.australia.fill",   titleKey: "封疆大吏",   descriptionKey: "领地总面积达到 1 km²",  condition: .totalTerritoryArea(1_000_000)),
        AchievementDefinition(id: "buildings_50",    chapter: .pioneer, icon: "building.2.fill",             titleKey: "城市规划师", descriptionKey: "建造 50 座建筑",        condition: .buildingCount(50)),
        AchievementDefinition(id: "exploration_100", chapter: .pioneer, icon: "star.fill",                   titleKey: "百战老将",   descriptionKey: "累计完成 100 次探索",   condition: .explorationCount(100)),

        // MARK: Chapter 4: 缔造·新世界
        AchievementDefinition(id: "distance_1000km",  chapter: .legend, icon: "figure.walk",           titleKey: "旷世奇行",   descriptionKey: "累计探索 1,000 公里",    condition: .totalDistance(1_000_000)),
        AchievementDefinition(id: "territory_5km2",   chapter: .legend, icon: "map",                   titleKey: "末日帝国",   descriptionKey: "领地总面积达到 5 km²",  condition: .totalTerritoryArea(5_000_000)),
        AchievementDefinition(id: "buildings_100",    chapter: .legend, icon: "building.columns",      titleKey: "传奇建造者", descriptionKey: "建造 100 座建筑",        condition: .buildingCount(100)),
        AchievementDefinition(id: "exploration_200",  chapter: .legend, icon: "crown.fill",            titleKey: "废土传奇",   descriptionKey: "累计完成 200 次探索",   condition: .explorationCount(200)),
    ]
}

// MARK: - Progress

struct AchievementProgress: Identifiable {
    let definition: AchievementDefinition
    var currentValue: Double
    var isUnlocked: Bool

    var id: String { definition.id }

    var progressRatio: Double {
        let target = definition.targetValue
        guard target > 0 else { return isUnlocked ? 1.0 : 0.0 }
        return min(currentValue / target, 1.0)
    }

    var formattedCurrent: String {
        switch definition.condition {
        case .totalDistance:
            if currentValue >= 1000 { return String(format: "%.1f km", currentValue / 1000) }
            return String(format: "%.0f m", currentValue)
        case .totalTerritoryArea:
            if currentValue >= 1_000_000 { return String(format: "%.2f km²", currentValue / 1_000_000) }
            if currentValue >= 1000 { return String(format: "%.0f k m²", currentValue / 1000) }
            return String(format: "%.0f m²", currentValue)
        default:
            return String(format: "%.0f", currentValue)
        }
    }

    var formattedTarget: String {
        let t = definition.targetValue
        switch definition.condition {
        case .totalDistance:
            if t >= 1000 { return String(format: "%.0f km", t / 1000) }
            return String(format: "%.0f m", t)
        case .totalTerritoryArea:
            if t >= 1_000_000 { return String(format: "%.0f km²", t / 1_000_000) }
            return String(format: "%.0f m²", t)
        default:
            return String(format: "%.0f", t)
        }
    }
}
