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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private let logger = ExplorationLogger.shared

    private init() {}

    // MARK: - 容量

    /// 所有 active 仓库建筑的总容量
    var totalCapacity: Int {
        let templates = BuildingManager.shared.buildingTemplates
        return BuildingManager.shared.playerBuildings
            .filter { $0.status == .active }
            .compactMap { building -> Int? in
                guard let template = templates.first(where: { $0.id == building.templateId }),
                      template.isStorage else { return nil }
                return template.storageCapacity(at: building.level)
            }
            .reduce(0, +)
    }

    var usedCapacity: Int { items.reduce(0) { $0 + $1.quantity } }
    var remainingCapacity: Int { max(0, totalCapacity - usedCapacity) }
    var hasWarehouse: Bool { totalCapacity > 0 }

    // MARK: - 加载

    func refreshItems() async {
        guard AuthManager.shared.currentUser != nil else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

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
            logger.log("仓库加载完成：\(items.count) 种物品", type: .success)
        } catch {
            logger.logError("仓库加载失败", error: error)
        }
    }

    // MARK: - 存入（背包 → 仓库）

    func deposit(itemId: String, quantity: Int, quality: ItemQuality? = nil, customName: String? = nil) async throws {
        guard AuthManager.shared.currentUser != nil else { throw WarehouseError.notAuthenticated }
        guard hasWarehouse else { throw WarehouseError.noWarehouseBuilt }
        guard remainingCapacity >= quantity else { throw WarehouseError.warehouseFull }

        try await InventoryManager.shared.removeItem(itemId: itemId, quantity: quantity, quality: quality)

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
