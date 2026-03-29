//
//  WarehouseManager.swift
//  EarthLord
//
//  领地仓库管理器 - 管理仓库物品的存取
//

import Foundation
import Supabase
import Combine

// MARK: - WarehouseItem

struct WarehouseItem: Identifiable, Equatable {
    let id: UUID
    let itemId: String
    var quantity: Int
    let quality: ItemQuality?
    let customName: String?
}

// MARK: - WarehouseItemDB

private struct WarehouseItemDB: Codable {
    let id: String?
    let itemId: String
    let quantity: Int
    let quality: String?
    let customName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity
        case quality
        case customName = "custom_name"
    }
}

// MARK: - WarehouseError

enum WarehouseError: LocalizedError {
    case notAuthenticated
    case noWarehouseBuilt
    case warehouseFull
    case insufficientItems
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "用户未登录"
        case .noWarehouseBuilt:    return "尚未建造仓库"
        case .warehouseFull:       return "仓库已满"
        case .insufficientItems:   return "仓库物品数量不足"
        case .saveFailed(let msg): return "操作失败: \(msg)"
        }
    }
}

// MARK: - WarehouseManager

@MainActor
final class WarehouseManager: ObservableObject {

    static let shared = WarehouseManager()

    @Published var items: [WarehouseItem] = []
    @Published var totalCapacity: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private let logger = ExplorationLogger.shared

    private init() {}

    // MARK: - 容量

    var usedCapacity: Int { items.reduce(0) { $0 + $1.quantity } }
    var remainingCapacity: Int { max(0, totalCapacity - usedCapacity) }
    var hasWarehouse: Bool { totalCapacity > 0 }

    /// 按 itemId 合并后的展示列表（UI 用）
    var groupedItems: [WarehouseItem] {
        var totals: [(itemId: String, quantity: Int)] = []
        var seen: [String: Int] = [:]   // itemId → index in totals
        for item in items {
            if let idx = seen[item.itemId] {
                totals[idx].quantity += item.quantity
            } else {
                seen[item.itemId] = totals.count
                totals.append((itemId: item.itemId, quantity: item.quantity))
            }
        }
        return totals.map { entry in
            // 用第一条真实记录的 id，仅作 Identifiable 用途
            let firstId = items.first { $0.itemId == entry.itemId }?.id ?? UUID()
            return WarehouseItem(id: firstId, itemId: entry.itemId, quantity: entry.quantity, quality: nil, customName: nil)
        }
    }

    // MARK: - 加载

    func refreshItems() async {
        guard AuthManager.shared.currentUser != nil else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // 独立加载物品，失败不影响容量计算
        do {
            let response: [WarehouseItemDB] = try await supabase
                .from("warehouse_items")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            items = response.compactMap { db in
                guard let id = db.id.flatMap({ UUID(uuidString: $0) }) else { return nil }
                return WarehouseItem(
                    id: id,
                    itemId: db.itemId,
                    quantity: db.quantity,
                    quality: db.quality.flatMap { ItemQuality(rawValue: $0) },
                    customName: db.customName
                )
            }
        } catch {
            logger.logError("仓库物品加载失败", error: error)
        }

        // 独立计算容量，失败不影响物品列表
        do {
            totalCapacity = try await fetchStorageCapacity()
            logger.log("仓库加载完成：\(items.count) 种物品，总容量 \(totalCapacity)", type: .success)
        } catch {
            logger.logError("仓库容量计算失败", error: error)
        }
    }

    /// 查询当前用户所有领地中 active 仓库建筑的总容量
    /// 不依赖 BuildingManager 内存状态，直接查询数据库
    private func fetchStorageCapacity() async throws -> Int {
        guard let userId = AuthManager.shared.currentUser?.id else { return 0 }

        struct BuildingRow: Codable {
            let templateId: String
            let level: Int
            enum CodingKeys: String, CodingKey {
                case templateId = "template_id"
                case level
            }
        }

        let buildings: [BuildingRow] = try await supabase
            .from("player_buildings")
            .select("template_id, level")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "active")
            .execute()
            .value

        // 容量表硬编码，不依赖模板是否已加载
        return buildings.reduce(0) { total, row in
            switch row.templateId {
            case "storage_small":
                let capacities = [500, 800, 1200]
                return total + capacities[max(0, min(row.level - 1, capacities.count - 1))]
            case "storage_medium":
                let capacities = [1500, 2000, 3000]
                return total + capacities[max(0, min(row.level - 1, capacities.count - 1))]
            default:
                return total
            }
        }
    }

    // MARK: - 存入（背包 → 仓库）

    func deposit(itemId: String, quantity: Int, quality: ItemQuality? = nil, customName: String? = nil) async throws {
        guard AuthManager.shared.currentUser != nil else { throw WarehouseError.notAuthenticated }
        guard hasWarehouse else { throw WarehouseError.noWarehouseBuilt }
        guard remainingCapacity >= quantity else { throw WarehouseError.warehouseFull }

        // quality == nil 时不限品质，合并扣除背包中所有同类物品
        let ignoreQuality = (quality == nil)
        try await InventoryManager.shared.removeItem(itemId: itemId, quantity: quantity, quality: quality, ignoreQuality: ignoreQuality)

        do {
            try await upsertItem(itemId: itemId, delta: +quantity, quality: quality, customName: customName)
        } catch {
            try? await InventoryManager.shared.addItem(itemId: itemId, quantity: quantity, quality: quality, customName: customName)
            throw WarehouseError.saveFailed(error.localizedDescription)
        }

        await InventoryManager.shared.refreshInventory()
        await refreshItems()
        logger.log("背包 → 仓库：\(itemId) x\(quantity)", type: .success)
    }

    // MARK: - 取出（仓库 → 背包）

    /// 按 itemId 取出（合并展示后使用，自动跨多条记录扣除）
    func withdrawByItemId(itemId: String, quantity: Int) async throws {
        guard AuthManager.shared.currentUser != nil else { throw WarehouseError.notAuthenticated }
        let totalInWarehouse = items.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
        guard totalInWarehouse >= quantity else { throw WarehouseError.insufficientItems }
        guard InventoryManager.shared.remainingCapacity >= quantity else { throw InventoryError.backpackFull }

        // 跨多条记录扣除
        let matching = items.filter { $0.itemId == itemId }.sorted { $0.quantity > $1.quantity }
        var remaining = quantity
        for warehouseItem in matching {
            guard remaining > 0 else { break }
            let deduct = min(warehouseItem.quantity, remaining)
            try await deductItem(id: warehouseItem.id, quantity: deduct, current: warehouseItem.quantity)
            remaining -= deduct
        }

        try await InventoryManager.shared.addItem(itemId: itemId, quantity: quantity, obtainedFrom: "warehouse")
        await InventoryManager.shared.refreshInventory()
        await refreshItems()
        logger.log("仓库 → 背包：\(itemId) x\(quantity)", type: .success)
    }

    func withdraw(item: WarehouseItem, quantity: Int) async throws {
        guard AuthManager.shared.currentUser != nil else { throw WarehouseError.notAuthenticated }
        guard item.quantity >= quantity else { throw WarehouseError.insufficientItems }
        guard InventoryManager.shared.remainingCapacity >= quantity else { throw InventoryError.backpackFull }

        try await deductItem(id: item.id, quantity: quantity, current: item.quantity)

        do {
            try await InventoryManager.shared.addItem(
                itemId: item.itemId,
                quantity: quantity,
                quality: item.quality,
                customName: item.customName
            )
        } catch {
            try? await upsertItem(itemId: item.itemId, delta: +quantity, quality: item.quality, customName: item.customName)
            throw WarehouseError.saveFailed(error.localizedDescription)
        }

        await InventoryManager.shared.refreshInventory()
        await refreshItems()
        logger.log("仓库 → 背包：\(item.itemId) x\(quantity)", type: .success)
    }

    // MARK: - 邮件直接入仓（不经过背包）

    /// 将邮件物品直接存入仓库（跳过背包）
    func receiveFromMail(itemId: String, quantity: Int, quality: ItemQuality?, customName: String? = nil) async throws {
        guard AuthManager.shared.currentUser != nil else { throw WarehouseError.notAuthenticated }
        guard hasWarehouse else { throw WarehouseError.noWarehouseBuilt }
        guard remainingCapacity >= quantity else { throw WarehouseError.warehouseFull }
        try await upsertItem(itemId: itemId, delta: +quantity, quality: quality, customName: customName)
        await refreshItems()
        logger.log("邮件 → 仓库：\(itemId) x\(quantity)", type: .success)
    }

    // MARK: - 建筑产出入仓

    func receiveOutput(itemId: String, quantity: Int) async {
        guard hasWarehouse else {
            logger.log("无仓库，产出丢弃：\(itemId) x\(quantity)", type: .warning)
            return
        }
        guard remainingCapacity >= quantity else {
            logger.log("仓库已满，产出丢弃：\(itemId) x\(quantity)", type: .warning)
            return
        }
        do {
            try await upsertItem(itemId: itemId, delta: +quantity, quality: nil, customName: nil)
            await refreshItems()
            logger.log("产出入仓：\(itemId) x\(quantity)", type: .success)
        } catch {
            logger.logError("产出入仓失败", error: error)
        }
    }

    // MARK: - 建造扣除（仓库直接减，不经过背包）

    /// 建造时从仓库扣除材料（背包不足时补充）
    func deductForConstruction(itemId: String, quantity: Int) async throws {
        let matching = items.filter { $0.itemId == itemId }.sorted { $0.quantity > $1.quantity }
        var remaining = quantity
        for warehouseItem in matching {
            guard remaining > 0 else { break }
            let deduct = min(warehouseItem.quantity, remaining)
            try await deductItem(id: warehouseItem.id, quantity: deduct, current: warehouseItem.quantity)
            remaining -= deduct
        }
        if remaining > 0 {
            throw WarehouseError.insufficientItems
        }
        await refreshItems()
    }

    // MARK: - Private

    private func upsertItem(itemId: String, delta: Int, quality: ItemQuality?, customName: String?) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else { throw WarehouseError.notAuthenticated }

        var query = supabase
            .from("warehouse_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("item_id", value: itemId)

        if let quality = quality {
            query = query.eq("quality", value: quality.rawValue)
        } else {
            query = query.is("quality", value: nil)
        }

        let existing: [WarehouseItemDB] = try await query.execute().value

        if let first = existing.first, let existingId = first.id {
            let newQty = first.quantity + delta
            if newQty <= 0 {
                try await supabase.from("warehouse_items").delete().eq("id", value: existingId).execute()
            } else {
                try await supabase.from("warehouse_items").update(["quantity": newQty]).eq("id", value: existingId).execute()
            }
        } else if delta > 0 {
            let data: [String: AnyJSON] = [
                "user_id":     .string(userId.uuidString),
                "item_id":     .string(itemId),
                "quantity":    .integer(delta),
                "quality":     quality != nil ? .string(quality!.rawValue) : .null,
                "custom_name": customName != nil ? .string(customName!) : .null
            ]
            try await supabase.from("warehouse_items").insert(data).execute()
        }
    }

    private func deductItem(id: UUID, quantity: Int, current: Int) async throws {
        let newQty = current - quantity
        if newQty <= 0 {
            try await supabase.from("warehouse_items").delete().eq("id", value: id.uuidString).execute()
        } else {
            try await supabase.from("warehouse_items").update(["quantity": newQty]).eq("id", value: id.uuidString).execute()
        }
    }
}
