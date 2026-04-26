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
    var health: Double?
    var lastVitalsUpdate: Date?

    enum CodingKeys: String, CodingKey {
        case satiety
        case hydration
        case health
        case lastVitalsUpdate = "last_vitals_update"
    }
}

struct VitalsUpdate: Encodable {
    let satiety: Double
    let hydration: Double
    let health: Double
    let last_vitals_update: String
}

struct ItemVitalEffect {
    let satietyBoost: Double
    let hydrationBoost: Double
    let healthBoost: Double

    init(satietyBoost: Double = 0, hydrationBoost: Double = 0, healthBoost: Double = 0) {
        self.satietyBoost = satietyBoost
        self.hydrationBoost = hydrationBoost
        self.healthBoost = healthBoost
    }
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
    @Published var health: Double = 100      // 0–100
    @Published var isLoading = false

    // 每小时衰减量（基准）
    private let satietyDecayPerHour:  Double = 1.0   // 空腹：100h ≈ 4.2天
    private let hydrationDecayPerHour: Double = 2.0  // 缺水：50h  ≈ 2.1天

    // MARK: - Computed

    var coreLife: Double {
        // 水分最关键(40%) 健康值(35%) 饱食度(25%)
        min(max(hydration * 0.40 + health * 0.35 + satiety * 0.25, 0), 100)
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
        case .lord:     return "physique.buff.lord"
        case .explorer: return "physique.buff.explorer"
        case .free:     return nil
        }
    }

    /// 当前建筑提供的体征衰减加成描述（有加成时显示）
    var buildingDecayBuffDescription: String? {
        let reduction = BuildingManager.shared.vitalDecayReduction
        guard reduction > 0 else { return nil }
        return String(format: LanguageManager.shared.localizedString(for: "physique.buff.building"), Int(reduction * 100))
    }

    // MARK: - Load

    func load() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let row: ProfileVitalsRow = try await SupabaseManager.shared.client
                .from("profiles")
                .select("satiety, hydration, health, last_vitals_update")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            let base = Date()
            let lastUpdate = row.lastVitalsUpdate ?? base
            // 最多计算72小时的衰减，防止长时间未登录后体征直接归零
            let elapsed = min(base.timeIntervalSince(lastUpdate) / 3600, 72.0)
            let mult = decayMultiplier

            let newSatiety   = min(max((row.satiety   ?? 80)  - elapsed * satietyDecayPerHour  * mult, 0), 100)
            let newHydration = min(max((row.hydration ?? 80)  - elapsed * hydrationDecayPerHour * mult, 0), 100)

            // 健康值：饱食/水分充足时自然恢复（+1/h），过低时衰减
            let healthDecay = healthDecayPerHour(satiety: newSatiety, hydration: newHydration)
            let healthRegen = (newSatiety > 60 && newHydration > 60) ? 1.0 : 0.0
            let healthNet = healthRegen - healthDecay  // 正值=恢复，负值=衰减
            let newHealth = min(max((row.health ?? 100) + elapsed * healthNet, 0), 100)

            satiety   = newSatiety
            hydration = newHydration
            health    = newHealth
            await saveVitals()
        } catch {
            satiety   = 80
            hydration = 80
            await saveVitals()
        }
    }

    // MARK: - Use Item

    /// 健康值每小时衰减量（分级：轻度/中度/重度）
    private func healthDecayPerHour(satiety: Double, hydration: Double) -> Double {
        var decay = 0.0
        // 水分衰减：< 30 轻度，< 15 重度
        if hydration < 30 { decay += 1.5 }
        if hydration < 15 { decay += 1.5 }
        // 饱食衰减：< 30 轻度，< 15 重度
        if satiety < 30   { decay += 1.0 }
        if satiety < 15   { decay += 1.0 }
        return decay
    }

    func canUse(itemId: String) -> Bool {
        let e = effect(for: itemId)
        return e.satietyBoost > 0 || e.hydrationBoost > 0 || e.healthBoost > 0
    }

    /// 返回物品的体征回复数值（供 UI 展示用）
    func vitalEffect(for itemId: String) -> ItemVitalEffect {
        effect(for: itemId)
    }

    func useItem(_ item: BackpackItem) async throws {
        let e = effect(for: item.itemId)
        guard e.satietyBoost > 0 || e.hydrationBoost > 0 || e.healthBoost > 0 else {
            throw PhysiqueError.notConsumable
        }
        satiety   = min(satiety   + e.satietyBoost,  100)
        hydration = min(hydration + e.hydrationBoost, 100)
        // 医疗物品健康回复：有医疗站时×1.2
        if e.healthBoost > 0 {
            let bonus = BuildingManager.shared.medicalHealBonus
            health = min(health + e.healthBoost * bonus, 100)
        }
        await saveVitals()
        try await InventoryManager.shared.useItem(inventoryId: item.id, quantity: 1)
    }

    private func effect(for itemId: String) -> ItemVitalEffect {
        switch itemId {
        // 饮料
        case "water_bottle":       return ItemVitalEffect(satietyBoost:  0, hydrationBoost: 30)
        case "energy_drink":       return ItemVitalEffect(satietyBoost:  5, hydrationBoost: 20)
        case "cola":               return ItemVitalEffect(satietyBoost: 15, hydrationBoost: 15)
        case "juice":              return ItemVitalEffect(satietyBoost: 15, hydrationBoost: 25)
        case "sports_drink":       return ItemVitalEffect(satietyBoost:  5, hydrationBoost: 40)
        // 食物
        case "canned_food":        return ItemVitalEffect(satietyBoost: 40, hydrationBoost:  5)
        case "bread":              return ItemVitalEffect(satietyBoost: 25, hydrationBoost:  0)
        case "instant_noodles":    return ItemVitalEffect(satietyBoost: 30, hydrationBoost: 10)
        case "chocolate":          return ItemVitalEffect(satietyBoost: 25, hydrationBoost:  0)
        case "compressed_biscuit": return ItemVitalEffect(satietyBoost: 35, hydrationBoost:  0)
        case "hardtack":           return ItemVitalEffect(satietyBoost: 40, hydrationBoost:  0)
        case "canned_meat":        return ItemVitalEffect(satietyBoost: 55, hydrationBoost:  5)
        // 农业产出
        case "vegetable":          return ItemVitalEffect(satietyBoost: 15, hydrationBoost:  5)
        case "fruit":              return ItemVitalEffect(satietyBoost: 10, hydrationBoost: 10)
        case "grain":              return ItemVitalEffect(satietyBoost: 25, hydrationBoost:  0)
        // 医疗
        case "bandage":            return ItemVitalEffect(healthBoost:  8)
        case "medicine":           return ItemVitalEffect(healthBoost: 15)
        case "first_aid_kit":      return ItemVitalEffect(healthBoost: 30)
        case "antibiotics":        return ItemVitalEffect(healthBoost: 25)
        default:                   return ItemVitalEffect()
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
        // 探索超过2km时健康值额外消耗
        if distanceKm > 2.0 {
            let healthCost = min((distanceKm - 2.0) * 2.5, 10.0)
            health = max(health - healthCost, 0)
        }
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
            health: health,
            last_vitals_update: ISO8601DateFormatter().string(from: Date())
        )
        _ = try? await SupabaseManager.shared.client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
    }
}
