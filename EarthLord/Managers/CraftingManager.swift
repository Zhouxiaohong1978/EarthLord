// CraftingManager.swift
// EarthLord — 工作台合成系统

import Foundation
import SwiftUI

// MARK: - Models

struct CraftingRecipe: Identifiable {
    let id: String
    let buildingTemplateId: String  // 所属建筑
    let inputs: [String: Int]       // itemId → 数量
    let outputItemId: String
    let outputQuantity: Int
    let durationSeconds: Int

    var durationFormatted: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct CraftingJob: Identifiable, Codable {
    let id: UUID
    let recipeId: String
    let outputItemId: String
    let outputQuantity: Int
    let startedAt: Date
    let completedAt: Date
    var collected: Bool

    var isComplete: Bool { Date() >= completedAt }

    var progress: Double {
        let total = completedAt.timeIntervalSince(startedAt)
        let elapsed = Date().timeIntervalSince(startedAt)
        return min(1.0, max(0.0, elapsed / total))
    }

    var remainingSeconds: Double {
        max(0, completedAt.timeIntervalSince(Date()))
    }

    var remainingFormatted: String {
        let secs = Int(remainingSeconds)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Manager

@MainActor
final class CraftingManager: ObservableObject {
    static let shared = CraftingManager()
    private let logger = ExplorationLogger.shared
    private let jobsKey = "crafting_jobs"
    private init() { loadJobs() }

    @Published var activeJobs: [CraftingJob] = []
    @Published var isLoading = false

    // MARK: - Recipes

    let recipes: [CraftingRecipe] = [
        // 工作台配方
        CraftingRecipe(
            id: "cloth_to_bandage",
            buildingTemplateId: "workbench",
            inputs: ["cloth": 3],
            outputItemId: "bandage",
            outputQuantity: 2,
            durationSeconds: 3600
        ),
        CraftingRecipe(
            id: "cloth_to_rope",
            buildingTemplateId: "workbench",
            inputs: ["cloth": 2],
            outputItemId: "rope",
            outputQuantity: 1,
            durationSeconds: 1800
        ),
        CraftingRecipe(
            id: "metal_to_nails",
            buildingTemplateId: "workbench",
            inputs: ["scrap_metal": 3],
            outputItemId: "nails",
            outputQuantity: 10,
            durationSeconds: 1800
        ),
        CraftingRecipe(
            id: "metal_to_tool",
            buildingTemplateId: "workbench",
            inputs: ["scrap_metal": 5, "wood": 3],
            outputItemId: "tool",
            outputQuantity: 1,
            durationSeconds: 7200
        ),
        CraftingRecipe(
            id: "tool_to_toolbox",
            buildingTemplateId: "workbench",
            inputs: ["scrap_metal": 10, "tool": 2],
            outputItemId: "toolbox",
            outputQuantity: 1,
            durationSeconds: 14400
        ),
        // 食品加工厂配方
        CraftingRecipe(
            id: "grain_to_bread",
            buildingTemplateId: "food_factory",
            inputs: ["grain": 3],
            outputItemId: "bread",
            outputQuantity: 2,
            durationSeconds: 3600
        ),
        CraftingRecipe(
            id: "grain_to_hardtack",
            buildingTemplateId: "food_factory",
            inputs: ["grain": 5, "cloth": 1],
            outputItemId: "hardtack",
            outputQuantity: 3,
            durationSeconds: 5400
        ),
        CraftingRecipe(
            id: "vegetable_to_canned",
            buildingTemplateId: "food_factory",
            inputs: ["vegetable": 4, "scrap_metal": 2],
            outputItemId: "canned_food",
            outputQuantity: 2,
            durationSeconds: 7200
        ),
        CraftingRecipe(
            id: "fruit_to_juice",
            buildingTemplateId: "food_factory",
            inputs: ["fruit": 3],
            outputItemId: "juice",
            outputQuantity: 2,
            durationSeconds: 2700
        ),
        // 装备强化台配方
        CraftingRecipe(
            id: "rare_to_epic",
            buildingTemplateId: "equipment_forge",
            inputs: ["equipment_rare": 3],
            outputItemId: "equipment_epic",
            outputQuantity: 1,
            durationSeconds: 86400
        ),
        CraftingRecipe(
            id: "epic_to_rare",
            buildingTemplateId: "equipment_forge",
            inputs: ["equipment_epic": 1],
            outputItemId: "equipment_rare",
            outputQuantity: 2,
            durationSeconds: 14400
        ),
    ]

    func recipes(for buildingTemplateId: String) -> [CraftingRecipe] {
        recipes.filter { $0.buildingTemplateId == buildingTemplateId }
    }

    // MARK: - Slot Management

    /// 工作台最大并发合成槽位（基于等级）
    func maxSlots(buildingLevel: Int) -> Int {
        return buildingLevel  // Lv1=1, Lv2=2, Lv3=3
    }

    /// 当前活跃（未领取）任务数
    var activeJobCount: Int {
        activeJobs.filter { !$0.collected }.count
    }

    // MARK: - Resource Check

    /// 检查背包+仓库是否有足够材料
    func canCraft(recipe: CraftingRecipe) -> (ok: Bool, missing: [String: Int]) {
        var available: [String: Int] = [:]
        for item in InventoryManager.shared.items where item.customName == nil {
            available[item.itemId, default: 0] += item.quantity
        }
        for item in WarehouseManager.shared.items where item.customName == nil {
            available[item.itemId, default: 0] += item.quantity
        }
        var missing: [String: Int] = [:]
        for (itemId, required) in recipe.inputs {
            let owned = available[itemId] ?? 0
            if owned < required { missing[itemId] = required - owned }
        }
        return (missing.isEmpty, missing)
    }

    // MARK: - Start Crafting

    func startCrafting(recipe: CraftingRecipe, buildingLevel: Int) async throws {
        guard activeJobCount < maxSlots(buildingLevel: buildingLevel) else {
            throw CraftingError.slotsFull
        }
        let (ok, missing) = canCraft(recipe: recipe)
        guard ok else { throw CraftingError.insufficientResources(missing) }

        isLoading = true
        defer { isLoading = false }

        // 扣除材料：先背包，再仓库
        for (itemId, required) in recipe.inputs {
            var remaining = required
            let backpackItems = InventoryManager.shared.items
                .filter { $0.itemId == itemId && $0.customName == nil }
                .sorted { $0.quantity > $1.quantity }
            for item in backpackItems {
                guard remaining > 0 else { break }
                let use = min(item.quantity, remaining)
                try await InventoryManager.shared.useItem(inventoryId: item.id, quantity: use)
                remaining -= use
            }
            if remaining > 0 {
                try await WarehouseManager.shared.deductForConstruction(itemId: itemId, quantity: remaining)
            }
        }

        let now = Date()
        let job = CraftingJob(
            id: UUID(),
            recipeId: recipe.id,
            outputItemId: recipe.outputItemId,
            outputQuantity: recipe.outputQuantity,
            startedAt: now,
            completedAt: now.addingTimeInterval(TimeInterval(recipe.durationSeconds)),
            collected: false
        )
        activeJobs.append(job)
        saveJobs()
        logger.log("开始合成: \(recipe.id) → \(recipe.outputItemId)×\(recipe.outputQuantity)", type: .success)
    }

    // MARK: - Collect

    func collectJob(jobId: UUID, toWarehouse: Bool = false) async throws {
        guard let index = activeJobs.firstIndex(where: { $0.id == jobId }) else { return }
        let job = activeJobs[index]
        guard job.isComplete, !job.collected else { return }

        isLoading = true
        defer { isLoading = false }

        if toWarehouse {
            guard WarehouseManager.shared.hasWarehouse else { throw WarehouseError.noWarehouseBuilt }
            guard WarehouseManager.shared.remainingCapacity >= job.outputQuantity else { throw WarehouseError.warehouseFull }
            await WarehouseManager.shared.receiveOutput(itemId: job.outputItemId, quantity: job.outputQuantity)
        } else {
            try await InventoryManager.shared.addItem(
                itemId: job.outputItemId,
                quantity: job.outputQuantity,
                obtainedFrom: "crafting"
            )
        }

        activeJobs[index].collected = true
        saveJobs()
        logger.log("领取合成: \(job.outputItemId)×\(job.outputQuantity)", type: .success)
    }

    // MARK: - Persistence (UserDefaults)

    private func saveJobs() {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        // 只保留未领取或7天内完成的任务
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        let toSave = activeJobs.filter { !$0.collected || $0.completedAt > cutoff }
        activeJobs = toSave
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "\(jobsKey)_\(userId)")
        }
    }

    private func loadJobs() {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        guard let data = UserDefaults.standard.data(forKey: "\(jobsKey)_\(userId)"),
              let jobs = try? JSONDecoder().decode([CraftingJob].self, from: data) else { return }
        // 过滤掉已领取的
        activeJobs = jobs.filter { !$0.collected }
    }

    func reloadForCurrentUser() {
        loadJobs()
    }
}

// MARK: - Errors

enum CraftingError: LocalizedError {
    case slotsFull
    case insufficientResources([String: Int])

    var errorDescription: String? {
        switch self {
        case .slotsFull:
            return String(localized: "合成槽位已满，请先领取已完成的任务")
        case .insufficientResources:
            return String(localized: "材料不足")
        }
    }
}
