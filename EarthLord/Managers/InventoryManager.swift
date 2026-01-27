//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器 - 管理玩家背包物品的增删改查
//

import Foundation
import Supabase
import Combine

// MARK: - InventoryError

/// 背包操作错误类型
enum InventoryError: LocalizedError {
    case notAuthenticated
    case itemNotFound
    case insufficientQuantity
    case saveFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .insufficientQuantity:
            return "物品数量不足"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }
    }
}

// MARK: - InventoryManager

/// 背包管理器（单例）
@MainActor
final class InventoryManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 背包物品列表
    @Published var items: [BackpackItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 日志器
    private let logger = ExplorationLogger.shared

    // MARK: - Initialization

    private init() {
        logger.log("InventoryManager 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 获取用户背包所有物品（包括关联账号的物品）
    /// - Returns: 背包物品列表
    func getInventory() async throws -> [BackpackItem] {
        guard AuthManager.shared.currentUser != nil else {
            throw InventoryError.notAuthenticated
        }

        logger.log("开始加载背包数据...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            // 不手动过滤 user_id，依赖 RLS 策略返回关联账号的数据
            let response: [InventoryItemDB] = try await supabase
                .from("inventory_items")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            // 转换为 BackpackItem
            let backpackItems = response.compactMap { dbItem -> BackpackItem? in
                guard let id = dbItem.id else { return nil }

                let quality: ItemQuality? = dbItem.quality.flatMap { ItemQuality(rawValue: $0) }

                let dateFormatter = ISO8601DateFormatter()
                let obtainedAt = dbItem.createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()

                return BackpackItem(
                    id: UUID(uuidString: id) ?? UUID(),
                    itemId: dbItem.itemId,
                    quantity: dbItem.quantity,
                    quality: quality,
                    obtainedAt: obtainedAt,
                    obtainedFrom: dbItem.obtainedFrom
                )
            }

            self.items = backpackItems
            logger.log("成功加载 \(backpackItems.count) 件背包物品", type: .success)

            // 缓存到本地
            OfflineSyncManager.shared.cacheInventory(backpackItems)

            return backpackItems

        } catch {
            logger.logError("加载背包失败，尝试从本地缓存加载", error: error)

            // 网络失败时从本地缓存加载
            if let cachedItems = OfflineSyncManager.shared.loadCachedInventory() {
                self.items = cachedItems
                logger.log("从本地缓存加载 \(cachedItems.count) 件背包物品", type: .info)
                return cachedItems
            }

            throw InventoryError.loadFailed(error.localizedDescription)
        }
    }

    /// 刷新背包（供 UI 调用）
    func refreshInventory() async {
        do {
            _ = try await getInventory()
            errorMessage = nil
        } catch {
            // 如果有缓存数据，不显示错误
            if !items.isEmpty {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    ///   - quality: 品质（可选）
    ///   - obtainedFrom: 获取来源（可选）
    ///   - sessionId: 探索会话ID（可选）
    func addItem(
        itemId: String,
        quantity: Int,
        quality: ItemQuality? = nil,
        obtainedFrom: String? = nil,
        sessionId: String? = nil
    ) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.log("添加物品: \(itemId) x\(quantity)", type: .info)

        // 检查是否已有相同物品（相同ID和品质）
        let existingItem = try await findExistingItem(
            userId: userId,
            itemId: itemId,
            quality: quality
        )

        if let existing = existingItem {
            // 已有物品，更新数量
            let newQuantity = existing.quantity + quantity
            try await updateItemQuantityInDB(itemId: existing.id!, newQuantity: newQuantity)
            logger.log("物品已存在，数量更新为 \(newQuantity)", type: .success)
        } else {
            // 新物品，插入记录
            let itemData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "item_id": .string(itemId),
                "quantity": .integer(quantity),
                "quality": quality != nil ? .string(quality!.rawValue) : .null,
                "obtained_from": obtainedFrom != nil ? .string(obtainedFrom!) : .null,
                "exploration_session_id": sessionId != nil ? .string(sessionId!) : .null
            ]

            try await supabase
                .from("inventory_items")
                .insert(itemData)
                .execute()

            logger.log("新物品已添加到背包", type: .success)
        }

        // 刷新本地数据
        await refreshInventory()
    }

    /// 更新物品数量
    /// - Parameters:
    ///   - inventoryId: 背包记录ID
    ///   - newQuantity: 新数量
    func updateItemQuantity(inventoryId: UUID, newQuantity: Int) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw InventoryError.notAuthenticated
        }

        if newQuantity <= 0 {
            // 数量为0，删除物品
            try await deleteItem(inventoryId: inventoryId)
            return
        }

        try await updateItemQuantityInDB(itemId: inventoryId.uuidString, newQuantity: newQuantity)
        logger.log("物品数量已更新为 \(newQuantity)", type: .success)

        // 刷新本地数据
        await refreshInventory()
    }

    /// 删除物品
    /// - Parameter inventoryId: 背包记录ID
    func deleteItem(inventoryId: UUID) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw InventoryError.notAuthenticated
        }

        logger.log("删除物品: \(inventoryId)", type: .info)

        try await supabase
            .from("inventory_items")
            .delete()
            .eq("id", value: inventoryId.uuidString)
            .execute()

        logger.log("物品已删除", type: .success)

        // 刷新本地数据
        await refreshInventory()
    }

    /// 使用物品（减少数量）
    /// - Parameters:
    ///   - inventoryId: 背包记录ID
    ///   - quantity: 使用数量
    func useItem(inventoryId: UUID, quantity: Int = 1) async throws {
        guard let item = items.first(where: { $0.id == inventoryId }) else {
            throw InventoryError.itemNotFound
        }

        if item.quantity < quantity {
            throw InventoryError.insufficientQuantity
        }

        let newQuantity = item.quantity - quantity
        try await updateItemQuantity(inventoryId: inventoryId, newQuantity: newQuantity)
    }

    /// 按分类获取物品
    /// - Parameter category: 物品分类
    /// - Returns: 该分类的物品列表
    func getItemsByCategory(_ category: ItemCategory) -> [BackpackItem] {
        return items.filter { item in
            guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                return false
            }
            return definition.category == category
        }
    }

    /// 获取背包物品总数
    var totalItemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    /// 获取背包总重量
    var totalWeight: Double {
        items.reduce(0) { total, item in
            guard let definition = MockExplorationData.getItemDefinition(by: item.itemId) else {
                return total
            }
            return total + definition.weight * Double(item.quantity)
        }
    }

    // MARK: - Private Methods

    /// 查找已存在的物品
    private func findExistingItem(
        userId: UUID,
        itemId: String,
        quality: ItemQuality?
    ) async throws -> InventoryItemDB? {
        var query = supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("item_id", value: itemId)

        if let quality = quality {
            query = query.eq("quality", value: quality.rawValue)
        } else {
            query = query.is("quality", value: nil)
        }

        let response: [InventoryItemDB] = try await query
            .limit(1)
            .execute()
            .value

        return response.first
    }

    /// 更新数据库中的物品数量
    private func updateItemQuantityInDB(itemId: String, newQuantity: Int) async throws {
        try await supabase
            .from("inventory_items")
            .update(["quantity": newQuantity])
            .eq("id", value: itemId)
            .execute()
    }

    // MARK: - 开发者测试方法

    #if DEBUG
    /// 添加测试资源（用于测试建造系统）
    /// - Returns: 是否添加成功
    @discardableResult
    func addTestResources() async -> Bool {
        guard AuthManager.shared.currentUser?.id != nil else {
            logger.log("添加测试资源失败：用户未登录", type: .error)
            return false
        }

        logger.log("开始添加测试资源...", type: .info)

        // 测试资源列表：物品ID -> 数量
        let testResources: [(itemId: String, quantity: Int)] = [
            ("wood", 200),           // 木材
            ("stone", 150),          // 石头
            ("scrap_metal", 100),    // 废金属
            ("glass", 50),           // 玻璃
            ("cloth", 80),           // 布料
            ("rope", 40),            // 绳子
            ("nails", 100),          // 钉子
            ("plastic", 60)          // 塑料
        ]

        var successCount = 0

        for resource in testResources {
            do {
                try await addItem(
                    itemId: resource.itemId,
                    quantity: resource.quantity,
                    quality: nil,
                    obtainedFrom: "测试添加"
                )
                successCount += 1
            } catch {
                logger.logError("添加测试资源失败: \(resource.itemId)", error: error)
            }
        }

        logger.log("测试资源添加完成：\(successCount)/\(testResources.count) 成功", type: successCount == testResources.count ? .success : .warning)

        return successCount > 0
    }

    /// 清空所有背包物品
    /// - Returns: 是否清空成功
    @discardableResult
    func clearAllItems() async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            logger.log("清空背包失败：用户未登录", type: .error)
            return false
        }

        logger.log("开始清空背包...", type: .info)

        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // 清空本地数据
            self.items = []

            logger.log("背包已清空", type: .success)
            return true

        } catch {
            logger.logError("清空背包失败", error: error)
            return false
        }
    }
    #endif
}
