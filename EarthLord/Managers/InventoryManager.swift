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
    case backpackFull
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
        case .backpackFull:
            return "背包已满，无法添加新物品"
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
                    obtainedFrom: dbItem.obtainedFrom,
                    customName: dbItem.customName,
                    customDescription: dbItem.customDescription
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
        sessionId: String? = nil,
        customName: String? = nil,
        customDescription: String? = nil
    ) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.log("添加物品: \(itemId) x\(quantity)", type: .info)

        // AI生成物品（有customName）保留独特名称，不与同类物品合并
        let existingItem: InventoryItemDB? = customName == nil ? try await findExistingItem(
            userId: userId,
            itemId: itemId,
            quality: quality
        ) : nil

        if let existing = existingItem {
            // 已有同类通用物品，直接叠加数量
            let newQuantity = existing.quantity + quantity
            try await updateItemQuantityInDB(itemId: existing.id!, newQuantity: newQuantity)
            logger.log("物品已存在，数量更新为 \(newQuantity)", type: .success)
        } else {
            // 新物品，检查背包容量
            if isBackpackFull {
                logger.log("背包已满 (\(itemTypeCount)/\(backpackCapacity))，无法添加新物品", type: .warning)
                throw InventoryError.backpackFull
            }

            // 插入记录
            let itemData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "item_id": .string(itemId),
                "quantity": .integer(quantity),
                "quality": quality != nil ? .string(quality!.rawValue) : .null,
                "obtained_from": obtainedFrom != nil ? .string(obtainedFrom!) : .null,
                "exploration_session_id": sessionId != nil ? .string(sessionId!) : .null,
                "custom_name": customName != nil ? .string(customName!) : .null,
                "custom_description": customDescription != nil ? .string(customDescription!) : .null
            ]

            try await supabase
                .from("inventory_items")
                .insert(itemData)
                .execute()

            logger.log("新物品已添加到背包 (当前 \(itemTypeCount + 1)/\(backpackCapacity))", type: .success)
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

    /// 从背包移除指定数量的物品（存入仓库时调用）
    func removeItem(itemId: String, quantity: Int, quality: ItemQuality? = nil, ignoreQuality: Bool = false) async throws {
        let matching = items.filter { $0.itemId == itemId && (ignoreQuality || $0.quality == quality) }
        let total = matching.reduce(0) { $0 + $1.quantity }
        guard total >= quantity else { throw InventoryError.insufficientQuantity }

        var remaining = quantity
        for item in matching {
            guard remaining > 0 else { break }
            let deduct = min(item.quantity, remaining)
            let newQty = item.quantity - deduct
            if newQty <= 0 {
                try await deleteItem(inventoryId: item.id)
            } else {
                try await updateItemQuantityInDB(itemId: item.id.uuidString, newQuantity: newQty)
            }
            remaining -= deduct
        }
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

    /// 获取背包物品种类数（不同的物品类型数量）
    var itemTypeCount: Int {
        items.count
    }

    /// 是否已购买扩容（Non-consumable，买一次永久 +500格）
    static let capacityExpansionKey = "backpack_capacity_expanded"
    var hasCapacityExpansion: Bool {
        get { UserDefaults.standard.bool(forKey: Self.capacityExpansionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.capacityExpansionKey) }
    }

    /// 获取背包容量上限（订阅档位 + 扩容加成）
    var backpackCapacity: Int {
        SubscriptionManager.shared.backpackCapacity + (hasCapacityExpansion ? 500 : 0)
    }

    /// 检查背包是否已满（按物品总数量）
    var isBackpackFull: Bool {
        totalItemCount >= backpackCapacity
    }

    /// 获取剩余背包容量（按物品总数量）
    var remainingCapacity: Int {
        max(0, backpackCapacity - totalItemCount)
    }

    // MARK: - 拆解

    /// 根据 AI 物品名称+描述推断应返还的标准材料 ID
    /// 名称和描述同时匹配，无命中则使用 fallback（原 item_id）
    static func classifyDisassembleMaterial(from name: String, description: String? = nil, fallback: String) -> String {
        let combined = name + (description.map { " " + $0 } ?? "")
        // 电子/科技类 → 电子元件
        // 工具类（描述中提到"工具"优先）→ 工具
        let toolHints = ["改装为工具", "用作工具", "当作工具", "制作工具", "简易工具", "充当工具"]
        if toolHints.contains(where: { combined.contains($0) }) { return "tool" }

        // 建造支撑/框架 → 废金属（铝/钢支架等）
        let buildHints = ["搭建庇护所", "庇护所支架", "建造支架", "搭建支架", "用于支撑", "临时支架"]
        if buildHints.contains(where: { combined.contains($0) }) { return "scrap_metal" }

        // 电子/科技类 → 电子元件
        let electronic = ["电池", "显卡", "芯片", "电路", "电子", "模块", "充电", "充电宝", "信号", "天线",
                          "雷达", "传感器", "处理器", "内存", "硬盘", "路由", "摄像", "屏幕", "面板", "主板",
                          "控制器", "变压器", "线圈", "继电器", "电源", "适配器", "数据线", "电容", "电阻"]
        if electronic.contains(where: { combined.contains($0) }) { return "electronic_component" }

        // 金属类 → 废金属
        let metal = ["金属", "钢铁", "铸铁", "合金", "铜", "铝", "铁", "钢", "齿轮", "螺丝", "螺母",
                     "轴承", "弹片", "链条", "锁具", "锁芯", "铆钉", "弹簧", "刀片", "钢管", "窗框", "门框"]
        if metal.contains(where: { combined.contains($0) }) { return "scrap_metal" }

        // 木制类 → 木材
        let wood = ["木", "板材", "竹", "木棍", "木框", "木架", "木箱", "树枝", "柴火", "桌腿",
                    "椅背", "木门", "木桌", "木椅", "托盘"]
        if wood.contains(where: { combined.contains($0) }) { return "wood" }

        // 石/混凝土类 → 石头
        let stone = ["混凝土", "水泥", "砖块", "石块", "岩石", "碎石", "石板", "石砖", "陶瓷", "瓷砖", "石材"]
        if stone.contains(where: { combined.contains($0) }) { return "stone" }

        // 布料/纤维/纸张类 → 布料
        let cloth = ["布料", "棉布", "纤维", "织物", "丝绸", "麻布", "帆布", "皮革", "衣物",
                     "编织", "毯子", "袋子", "画册", "书本", "纸张", "本子"]
        if cloth.contains(where: { combined.contains($0) }) { return "cloth" }

        // 玻璃类 → 玻璃
        let glass = ["玻璃", "镜片", "镜面", "透明板", "灯罩", "瓶身"]
        if glass.contains(where: { combined.contains($0) }) { return "glass" }

        // 绳索/线缆类 → 绳子
        let rope = ["绳索", "缆绳", "线缆", "束带", "捆绑带", "吊绳", "电线", "导线"]
        if rope.contains(where: { combined.contains($0) }) { return "rope" }

        // 医疗/化学类 → 绷带
        let medical = ["药剂", "绷带", "注射器", "医疗", "急救", "包扎", "消毒"]
        if medical.contains(where: { combined.contains($0) }) { return "bandage" }

        // 燃料/油类 → 燃料
        let fuel = ["燃料", "汽油", "柴油", "酒精", "可燃液", "油罐", "燃油"]
        if fuel.contains(where: { combined.contains($0) }) { return "fuel" }

        return fallback
    }

    /// 拆解 AI 命名物品，根据名称+描述推断材料类型，返还 60%（最少 1 个）
    @discardableResult
    func disassembleItem(_ item: BackpackItem) async throws -> (itemId: String, quantity: Int) {
        guard let customName = item.customName else { return (item.itemId, 0) }
        let returnItemId = InventoryManager.classifyDisassembleMaterial(from: customName, description: item.customDescription, fallback: item.itemId)
        let returnQty = max(1, Int(Double(item.quantity) * 0.6))
        try await deleteItem(inventoryId: item.id)
        try await addItem(itemId: returnItemId, quantity: returnQty, obtainedFrom: "拆解")
        logger.log("拆解: \(customName) → \(returnItemId) x\(returnQty)", type: .success)
        return (returnItemId, returnQty)
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
