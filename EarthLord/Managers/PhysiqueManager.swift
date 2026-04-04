//
//  PhysiqueManager.swift
//  EarthLord
//
//  体征系统 - 饱食度/水分实时衰减，通过使用背包物资恢复

import Foundation
import SwiftUI

// MARK: - Models

struct ProfileVitalsRow: Codable {
    var satiety: Double?
    var hydration: Double?
    var lastVitalsUpdate: Date?

    enum CodingKeys: String, CodingKey {
        case satiety
        case hydration
        case lastVitalsUpdate = "last_vitals_update"
    }
}

struct VitalsUpdate: Encodable {
    let satiety: Double
    let hydration: Double
    let last_vitals_update: String
}

struct ItemVitalEffect {
    let satietyBoost: Double
    let hydrationBoost: Double
}

enum PhysiqueStatus {
    case peak, good, tired, dying

    var labelKey: String {
        switch self {
        case .peak:  return "巅峰"
        case .good:  return "良好"
        case .tired: return "疲惫"
        case .dying: return "濒死"
        }
    }

    var color: Color {
        switch self {
        case .peak:  return ApocalypseTheme.success
        case .good:  return ApocalypseTheme.info
        case .tired: return ApocalypseTheme.warning
        case .dying: return ApocalypseTheme.danger
        }
    }
}

enum PhysiqueError: LocalizedError {
    case notConsumable
    var errorDescription: String? { "该物品无法食用或饮用" }
}

// MARK: - Manager

@MainActor
final class PhysiqueManager: ObservableObject {
    static let shared = PhysiqueManager()
    private let logger = ExplorationLogger.shared
    private init() {}

    @Published var satiety: Double = 80      // 0–100
    @Published var hydration: Double = 80    // 0–100
    @Published var isLoading = false

    // 每小时衰减量（基准）
    private let satietyDecayPerHour:  Double = 1.0   // 空腹：100h ≈ 4.2天
    private let hydrationDecayPerHour: Double = 2.0  // 缺水：50h  ≈ 2.1天

    // MARK: - Computed

    var coreLife: Double {
        min(max(satiety * 0.4 + hydration * 0.6, 0), 100)
    }

    var status: PhysiqueStatus {
        switch coreLife {
        case 70...: return .peak
        case 45...: return .good
        case 25...: return .tired
        default:    return .dying
        }
    }

    var hasWarning: Bool { satiety < 30 || hydration < 30 }

    var warningDescKey: String {
        if hydration < 30 && hydration <= satiety {
            return "严重缺水，请立即补充水分"
        }
        return "长时间未进食，体力急剧下降"
    }

    /// 基于当前较低体征的剩余存活小时数
    var hoursUntilDeath: Double {
        let mult = decayMultiplier
        let hSat  = satiety  / (satietyDecayPerHour  * mult)
        let hHyd  = hydration / (hydrationDecayPerHour * mult)
        return max(0, min(hSat, hHyd))
    }

    var daysUntilDeath: Int { Int(hoursUntilDeath / 24) }

    private var decayMultiplier: Double {
        let subscriptionMult: Double
        switch SubscriptionManager.shared.currentTier {
        case .lord:     subscriptionMult = 0.70
        case .explorer: subscriptionMult = 0.85
        case .free:     subscriptionMult = 1.00
        }
        let buildingReduction = BuildingManager.shared.vitalDecayReduction
        // 最低保留 30% 衰减速率，防止体征完全不减
        return max(0.30, subscriptionMult - buildingReduction)
    }

    var subscriptionBuffKey: String? {
        switch SubscriptionManager.shared.currentTier {
        case .lord:     return "领主光环：体征衰减 -30%"
        case .explorer: return "探索者加持：体征衰减 -15%"
        case .free:     return nil
        }
    }

    /// 当前建筑提供的体征衰减加成描述（有加成时显示）
    var buildingDecayBuffDescription: String? {
        let reduction = BuildingManager.shared.vitalDecayReduction
        guard reduction > 0 else { return nil }
        return "建筑庇护：体征衰减 -\(Int(reduction * 100))%"
    }

    // MARK: - Load

    func load() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let row: ProfileVitalsRow = try await SupabaseManager.shared.client
                .from("profiles")
                .select("satiety, hydration, last_vitals_update")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            let base = Date()
            let lastUpdate = row.lastVitalsUpdate ?? base
            // 最多计算72小时的衰减，防止长时间未登录后体征直接归零
            // 同时避免切换Tab时load()覆盖掉玩家刚用物品恢复的体征值
            let elapsed = min(base.timeIntervalSince(lastUpdate) / 3600, 72.0)
            let mult = decayMultiplier

            satiety  = min(max((row.satiety  ?? 80) - elapsed * satietyDecayPerHour  * mult, 0), 100)
            hydration = min(max((row.hydration ?? 80) - elapsed * hydrationDecayPerHour * mult, 0), 100)
            await saveVitals()
        } catch {
            satiety   = 80
            hydration = 80
            await saveVitals()
        }
    }

    // MARK: - Use Item

    func canUse(itemId: String) -> Bool {
        let e = effect(for: itemId)
        return e.satietyBoost > 0 || e.hydrationBoost > 0
    }

    func useItem(_ item: BackpackItem) async throws {
        let e = effect(for: item.itemId)
        guard e.satietyBoost > 0 || e.hydrationBoost > 0 else {
            throw PhysiqueError.notConsumable
        }
        satiety   = min(satiety   + e.satietyBoost,  100)
        hydration = min(hydration + e.hydrationBoost, 100)
        await saveVitals()
        try await InventoryManager.shared.useItem(inventoryId: item.id, quantity: 1)
    }

    private func effect(for itemId: String) -> ItemVitalEffect {
        switch itemId {
        case "water_bottle":  return ItemVitalEffect(satietyBoost:  0, hydrationBoost: 30)
        case "canned_food":   return ItemVitalEffect(satietyBoost: 40, hydrationBoost:  5)
        case "bread":         return ItemVitalEffect(satietyBoost: 25, hydrationBoost:  0)
        case "medicine":      return ItemVitalEffect(satietyBoost:  5, hydrationBoost:  5)
        case "first_aid_kit": return ItemVitalEffect(satietyBoost: 15, hydrationBoost: 15)
        case "antibiotics":   return ItemVitalEffect(satietyBoost: 10, hydrationBoost: 10)
        default:              return ItemVitalEffect(satietyBoost:  0, hydrationBoost:  0)
        }
    }

    // MARK: - 系统消耗（供其他系统调用）

    /// 探索时体征消耗（每次探索事件触发）
    /// - Parameter distanceKm: 探索距离（公里），影响消耗量
    func consumeByExploration(distanceKm: Double) async {
        let base = min(distanceKm * 0.5, 10.0)  // 每公里消耗0.5，最多10点
        let mult = decayMultiplier
        satiety   = max(satiety   - base * 0.6 * mult, 0)
        hydration = max(hydration - base * 0.8 * mult, 0)
        await saveVitals()
        logger.log("探索消耗体征: 饱食-\(String(format: "%.1f", base * 0.6 * mult)), 水分-\(String(format: "%.1f", base * 0.8 * mult))", type: .info)
    }

    /// 建造时体征消耗（开始建造时触发）
    /// - Parameter buildTimeSeconds: 建造时间（秒），影响消耗量
    func consumeByBuilding(buildTimeSeconds: Int) async {
        let hours = Double(buildTimeSeconds) / 3600.0
        let mult = decayMultiplier
        let satietyCost   = min(hours * satietyDecayPerHour   * mult * 1.5, 15.0)  // 建造比静止多50%消耗，最多15点
        let hydrationCost = min(hours * hydrationDecayPerHour * mult * 1.5, 15.0)
        satiety   = max(satiety   - satietyCost,   0)
        hydration = max(hydration - hydrationCost, 0)
        await saveVitals()
        logger.log("建造消耗体征: 饱食-\(String(format: "%.1f", satietyCost)), 水分-\(String(format: "%.1f", hydrationCost))", type: .info)
    }

    // MARK: - Save

    func saveVitals() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        let payload = VitalsUpdate(
            satiety: satiety,
            hydration: hydration,
            last_vitals_update: ISO8601DateFormatter().string(from: Date())
        )
        _ = try? await SupabaseManager.shared.client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
    }
}
