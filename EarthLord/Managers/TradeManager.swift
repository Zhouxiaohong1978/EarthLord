//
//  TradeManager.swift
//  EarthLord
//
//  交易管理器 - 管理玩家之间的异步挂单交易
//

import Foundation
import Supabase
import Combine

// MARK: - TradeManager

/// 交易管理器（单例）
@MainActor
final class TradeManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 市场可用挂单列表
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史列表
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 背包管理器
    private let inventoryManager = InventoryManager.shared

    /// 今日交易次数（用于限制检查）
    @Published var todayTradeCount: Int = 0

    /// 日志器
    private let logger = ExplorationLogger.shared

    /// 默认挂单有效期（秒）- 24小时
    private let defaultOfferDuration: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    private init() {
        logger.log("TradeManager 初始化完成", type: .info)
    }

    // MARK: - Create Offer

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 出售物品列表
    ///   - requestingItems: 求购物品列表
    ///   - message: 留言（可选）
    ///   - durationHours: 有效期（小时），默认24小时
    /// - Returns: 创建的挂单
    @discardableResult
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        durationHours: Int = 24
    ) async throws -> TradeOffer {
        guard let user = AuthManager.shared.currentUser else {
            throw TradeError.notAuthenticated
        }

        logger.log("创建交易挂单...", type: .info)
        isLoading = true
        defer { isLoading = false }

        // 检查每日交易限制
        try await checkDailyTradeLimit()

        // 验证出售物品库存
        let inventoryCheck = checkInventory(items: offeringItems)
        if !inventoryCheck.canAccept {
            throw TradeError.insufficientItems(inventoryCheck.missingItems)
        }

        // 锁定物品（从背包扣除，支持跨多条记录）
        var lockedItems: [TradeItem] = []
        do {
            for item in offeringItems {
                try await deductItemFromInventory(itemId: item.itemId, quantity: item.quantity, quality: item.quality)
                lockedItems.append(item)
                logger.log("锁定物品: \(item.itemId) x\(item.quantity)", type: .info)
            }
        } catch {
            // 锁定失败，退还已锁定的物品
            await returnItems(lockedItems)
            throw error
        }

        // 计算过期时间
        let now = Date()
        let expiresAt = now.addingTimeInterval(Double(durationHours) * 3600)

        // 编码物品为 JSON
        let encoder = JSONEncoder()
        guard let offeringData = try? encoder.encode(offeringItems),
              let offeringJson = String(data: offeringData, encoding: .utf8),
              let requestingData = try? encoder.encode(requestingItems),
              let requestingJson = String(data: requestingData, encoding: .utf8) else {
            throw TradeError.saveFailed("物品数据编码失败")
        }

        // 构建用户名
        let username = user.email ?? user.id.uuidString.prefix(8).description

        // 插入数据库
        let offerData: [String: AnyJSON] = [
            "owner_id": .string(user.id.uuidString),
            "owner_username": .string(username),
            "offering_items": .string(offeringJson),
            "requesting_items": .string(requestingJson),
            "status": .string(TradeOfferStatus.active.rawValue),
            "message": message != nil ? .string(message!) : .null,
            "expires_at": .string(expiresAt.ISO8601Format())
        ]

        do {
            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .insert(offerData)
                .select()
                .execute()
                .value

            guard let dbOffer = response.first,
                  let offer = dbOffer.toTradeOffer() else {
                throw TradeError.saveFailed("无法解析返回的挂单数据")
            }

            // 更新本地数据
            myOffers.insert(offer, at: 0)

            // 刷新库存数据
            await inventoryManager.refreshInventory()

            logger.log("交易挂单创建成功: \(offer.id)", type: .success)

            return offer

        } catch let error as TradeError {
            // 发生错误，尝试退还物品
            await returnItems(offeringItems)
            await inventoryManager.refreshInventory()
            throw error
        } catch {
            // 发生错误，尝试退还物品
            await returnItems(offeringItems)
            await inventoryManager.refreshInventory()
            logger.logError("创建挂单失败", error: error)
            throw TradeError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Accept Offer

    /// 接受交易挂单
    /// 使用数据库 RPC 函数实现原子性操作
    /// - Parameter offerId: 挂单ID
    /// - Returns: 交易历史记录
    @discardableResult
    func acceptOffer(offerId: UUID) async throws -> TradeHistory {
        guard let user = AuthManager.shared.currentUser else {
            throw TradeError.notAuthenticated
        }

        logger.log("接受交易挂单: \(offerId)", type: .info)
        isLoading = true
        defer { isLoading = false }

        // 检查每日交易限制
        try await checkDailyTradeLimit()

        // 获取挂单（用于本地验证和物品信息）
        guard let offer = availableOffers.first(where: { $0.id == offerId }) ??
                          myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 本地预验证（快速失败）
        guard offer.status == .active else {
            throw TradeError.invalidStatus
        }

        guard !offer.isExpired else {
            throw TradeError.offerExpired
        }

        guard offer.ownerId != user.id else {
            throw TradeError.cannotAcceptOwnOffer
        }

        // 验证买家库存（需要提供求购物品）
        let inventoryCheck = checkInventory(items: offer.requestingItems)
        if !inventoryCheck.canAccept {
            throw TradeError.insufficientItems(inventoryCheck.missingItems)
        }

        // 扣除买家物品（先扣除，RPC 失败时退还）
        var deductedItems: [TradeItem] = []
        do {
            for item in offer.requestingItems {
                try await deductItemFromInventory(itemId: item.itemId, quantity: item.quantity, quality: item.quality)
                deductedItems.append(item)
                logger.log("扣除买家物品: \(item.itemId) x\(item.quantity)", type: .info)
            }
        } catch {
            // 扣除失败，退还已扣除的物品
            await returnItems(deductedItems)
            throw error
        }

        let buyerUsername = user.email ?? user.id.uuidString.prefix(8).description

        // 构建交易物品数据
        let exchange = TradeExchange(
            sellerItems: offer.offeringItems,
            buyerItems: offer.requestingItems
        )

        // 将 TradeItem 数组转换为 AnyJSON 格式
        let sellerItemsJson: [AnyJSON] = offer.offeringItems.map { item in
            var dict: [String: AnyJSON] = [
                "itemId": .string(item.itemId),
                "quantity": .integer(item.quantity)
            ]
            if let quality = item.quality {
                dict["quality"] = .string(quality.rawValue)
            }
            return .object(dict)
        }

        let buyerItemsJson: [AnyJSON] = offer.requestingItems.map { item in
            var dict: [String: AnyJSON] = [
                "itemId": .string(item.itemId),
                "quantity": .integer(item.quantity)
            ]
            if let quality = item.quality {
                dict["quality"] = .string(quality.rawValue)
            }
            return .object(dict)
        }

        let itemsExchangedJson: AnyJSON = .object([
            "sellerItems": .array(sellerItemsJson),
            "buyerItems": .array(buyerItemsJson)
        ])

        // 调用 RPC 函数执行原子性交易
        do {
            let response: AcceptTradeRPCResult = try await supabase
                .rpc("accept_trade_offer", params: [
                    "p_offer_id": AnyJSON.string(offerId.uuidString),
                    "p_buyer_id": AnyJSON.string(user.id.uuidString),
                    "p_buyer_username": AnyJSON.string(buyerUsername),
                    "p_items_exchanged": itemsExchangedJson
                ])
                .execute()
                .value

            // 检查 RPC 执行结果
            guard response.success else {
                // RPC 失败，退还买家物品
                await returnItems(deductedItems)
                throw TradeError.saveFailed(response.message ?? response.error ?? "交易执行失败")
            }

            logger.log("RPC 交易执行成功: \(response.historyId ?? "unknown")", type: .success)

            // 刷新库存数据
            await inventoryManager.refreshInventory()

            // 创建本地历史对象
            let historyId = response.historyId.flatMap { UUID(uuidString: $0) } ?? UUID()
            let completedAt = response.completedAt ?? Date()

            let history = TradeHistory(
                id: historyId,
                offerId: offerId,
                sellerId: offer.ownerId,
                buyerId: user.id,
                sellerUsername: offer.ownerUsername,
                buyerUsername: buyerUsername,
                itemsExchanged: exchange,
                completedAt: completedAt
            )

            // 更新本地数据
            if let index = availableOffers.firstIndex(where: { $0.id == offerId }) {
                availableOffers.remove(at: index)
            }
            tradeHistory.insert(history, at: 0)

            logger.log("交易完成: \(history.id)", type: .success)

            return history

        } catch let error as TradeError {
            await inventoryManager.refreshInventory()
            throw error
        } catch {
            // 未知错误（RPC 调用失败、网络错误等），退还买家物品
            logger.logError("交易执行失败，正在退还物品...", error: error)
            await returnItems(deductedItems)
            await inventoryManager.refreshInventory()
            throw TradeError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Cancel Offer

    /// 取消交易挂单
    /// - Parameter offerId: 挂单ID
    func cancelOffer(offerId: UUID) async throws {
        guard let user = AuthManager.shared.currentUser else {
            throw TradeError.notAuthenticated
        }

        logger.log("取消交易挂单: \(offerId)", type: .info)
        isLoading = true
        defer { isLoading = false }

        // 获取挂单
        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 验证权限
        guard offer.ownerId == user.id else {
            throw TradeError.notParticipant
        }

        // 验证状态
        guard offer.status == .active else {
            throw TradeError.invalidStatus
        }

        // 退还锁定的物品
        await returnItems(offer.offeringItems)

        // 更新数据库状态
        try await supabase
            .from("trade_offers")
            .update(["status": TradeOfferStatus.cancelled.rawValue])
            .eq("id", value: offerId.uuidString)
            .execute()

        // 更新本地数据
        if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[index].status = .cancelled
        }

        // 刷新库存数据
        await inventoryManager.refreshInventory()

        logger.log("挂单已取消: \(offerId)", type: .success)
    }

    // MARK: - Fetch Methods

    /// 获取我的挂单列表
    @discardableResult
    func fetchMyOffers() async throws -> [TradeOffer] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        logger.log("加载我的挂单...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let offers = response.compactMap { $0.toTradeOffer() }
            self.myOffers = offers

            logger.log("成功加载 \(offers.count) 个挂单", type: .success)

            return offers

        } catch {
            logger.logError("加载我的挂单失败", error: error)
            throw TradeError.loadFailed(error.localizedDescription)
        }
    }

    /// 获取市场可用挂单
    @discardableResult
    func fetchAvailableOffers() async throws -> [TradeOffer] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        logger.log("加载市场挂单...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let now = Date()
            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: TradeOfferStatus.active.rawValue)
                .neq("owner_id", value: userId.uuidString)
                .gt("expires_at", value: now.ISO8601Format())
                .order("created_at", ascending: false)
                .execute()
                .value

            let offers = response.compactMap { $0.toTradeOffer() }
            self.availableOffers = offers

            logger.log("成功加载 \(offers.count) 个市场挂单", type: .success)

            return offers

        } catch {
            logger.logError("加载市场挂单失败", error: error)
            throw TradeError.loadFailed(error.localizedDescription)
        }
    }

    /// 获取交易历史
    @discardableResult
    func fetchTradeHistory() async throws -> [TradeHistory] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        logger.log("加载交易历史...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            // 查询参与的所有交易（作为卖家或买家）
            let response: [TradeHistoryDB] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            let history = response.compactMap { $0.toTradeHistory() }
            self.tradeHistory = history

            logger.log("成功加载 \(history.count) 条交易历史", type: .success)

            return history

        } catch {
            logger.logError("加载交易历史失败", error: error)
            throw TradeError.loadFailed(error.localizedDescription)
        }
    }

    /// 刷新所有数据
    func refreshAll() async {
        do {
            _ = try await fetchMyOffers()
            _ = try await fetchAvailableOffers()
            _ = try await fetchTradeHistory()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Rating

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史ID
    ///   - rating: 评分 (1-5)
    ///   - comment: 评论（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        guard let user = AuthManager.shared.currentUser else {
            throw TradeError.notAuthenticated
        }

        logger.log("评价交易: \(historyId), 评分: \(rating)", type: .info)

        // 获取交易历史
        guard let history = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }

        // 验证评分范围
        let validRating = max(1, min(5, rating))

        // 判断用户角色并检查是否已评价
        var updateData: [String: AnyJSON] = [:]

        if history.isSeller(userId: user.id) {
            if history.sellerRating != nil {
                throw TradeError.alreadyRated
            }
            updateData["seller_rating"] = .integer(validRating)
            if let comment = comment {
                updateData["seller_comment"] = .string(comment)
            }
        } else if history.isBuyer(userId: user.id) {
            if history.buyerRating != nil {
                throw TradeError.alreadyRated
            }
            updateData["buyer_rating"] = .integer(validRating)
            if let comment = comment {
                updateData["buyer_comment"] = .string(comment)
            }
        } else {
            throw TradeError.notParticipant
        }

        // 更新数据库
        try await supabase
            .from("trade_history")
            .update(updateData)
            .eq("id", value: historyId.uuidString)
            .execute()

        // 更新本地数据
        if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
            if history.isSeller(userId: user.id) {
                tradeHistory[index].sellerRating = validRating
                tradeHistory[index].sellerComment = comment
            } else {
                tradeHistory[index].buyerRating = validRating
                tradeHistory[index].buyerComment = comment
            }
        }

        logger.log("交易评价成功", type: .success)
    }

    // MARK: - Expire Check

    /// 检查并处理过期挂单
    func checkAndExpireOffers() async {
        logger.log("检查过期挂单...", type: .info)

        // 找出已过期但状态仍为 active 的挂单
        let expiredOffers = myOffers.filter { $0.isExpired && $0.status == .active }

        var hasProcessed = false

        for offer in expiredOffers {
            do {
                // 退还物品
                await returnItems(offer.offeringItems)

                // 更新数据库状态
                try await supabase
                    .from("trade_offers")
                    .update(["status": TradeOfferStatus.expired.rawValue])
                    .eq("id", value: offer.id.uuidString)
                    .execute()

                // 更新本地数据
                if let index = myOffers.firstIndex(where: { $0.id == offer.id }) {
                    myOffers[index].status = .expired
                }

                hasProcessed = true
                logger.log("挂单已过期处理: \(offer.id)", type: .info)

            } catch {
                logger.logError("处理过期挂单失败: \(offer.id)", error: error)
            }
        }

        // 如果有处理过期挂单，刷新库存
        if hasProcessed {
            await inventoryManager.refreshInventory()
        }
    }

    // MARK: - Helper Methods

    /// 检查库存是否充足
    /// - Parameter items: 需要检查的物品列表
    /// - Returns: 检查结果
    func checkInventory(items: [TradeItem]) -> CanAcceptTradeResult {
        var missingItems: [String: Int] = [:]

        for item in items {
            let available = getAvailableQuantity(itemId: item.itemId, quality: item.quality)
            if available < item.quantity {
                let itemName = MockExplorationData.getItemDefinition(by: item.itemId)?.name ?? item.itemId
                missingItems[itemName] = item.quantity - available
            }
        }

        if missingItems.isEmpty {
            return .success()
        } else {
            return .insufficientItems(missingItems)
        }
    }

    /// 获取指定物品的可用数量
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quality: 品质（可选）
    /// - Returns: 可用数量
    private func getAvailableQuantity(itemId: String, quality: ItemQuality?) -> Int {
        return inventoryManager.items
            .filter { $0.itemId == itemId && $0.quality == quality }
            .reduce(0) { $0 + $1.quantity }
    }

    /// 查找背包中的物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quality: 品质（可选）
    /// - Returns: 背包物品
    private func findInventoryItem(itemId: String, quality: ItemQuality?) -> BackpackItem? {
        return inventoryManager.items.first { $0.itemId == itemId && $0.quality == quality }
    }

    /// 从库存中扣除物品（支持跨多条记录扣除）
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 需要扣除的数量
    ///   - quality: 品质（可选）
    private func deductItemFromInventory(itemId: String, quantity: Int, quality: ItemQuality?) async throws {
        var remainingQuantity = quantity

        // 获取所有匹配的库存记录
        let matchingItems = inventoryManager.items.filter { $0.itemId == itemId && $0.quality == quality }

        for item in matchingItems {
            if remainingQuantity <= 0 { break }

            let deductAmount = min(item.quantity, remainingQuantity)
            try await inventoryManager.useItem(inventoryId: item.id, quantity: deductAmount)
            remainingQuantity -= deductAmount
        }

        if remainingQuantity > 0 {
            throw TradeError.insufficientItems([itemId: remainingQuantity])
        }
    }

    /// 退还物品到背包
    /// - Parameter items: 要退还的物品列表
    /// - Throws: 如果任何物品退还失败
    private func returnItems(_ items: [TradeItem]) async {
        var failedItems: [String] = []

        for item in items {
            do {
                try await inventoryManager.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "交易退还"
                )
                logger.log("退还物品: \(item.itemId) x\(item.quantity)", type: .info)
            } catch {
                logger.logError("退还物品失败: \(item.itemId)", error: error)
                failedItems.append(item.itemId)
            }
        }

        // 强制刷新库存以确保本地缓存同步
        await inventoryManager.refreshInventory()

        // 如果有失败的物品，记录警告
        if !failedItems.isEmpty {
            logger.log("警告：部分物品退还失败: \(failedItems.joined(separator: ", "))", type: .warning)
        }
    }

    /// 将物品转移给卖家
    /// - Parameters:
    ///   - sellerId: 卖家ID
    ///   - items: 要转移的物品列表
    private func transferItemsToSeller(sellerId: UUID, items: [TradeItem]) async throws {
        // 使用直接插入方式将物品添加到卖家背包
        for item in items {
            let itemData: [String: AnyJSON] = [
                "user_id": .string(sellerId.uuidString),
                "item_id": .string(item.itemId),
                "quantity": .integer(item.quantity),
                "quality": item.quality != nil ? .string(item.quality!.rawValue) : .null,
                "obtained_from": .string("交易获得")
            ]

            try await supabase
                .from("inventory_items")
                .insert(itemData)
                .execute()

            logger.log("卖家获得物品: \(item.itemId) x\(item.quantity)", type: .info)
        }
    }

    // MARK: - Daily Trade Limit

    /// 获取今日交易次数
    private func getTodayTradeCount() async throws -> Int {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 获取今天的开始时间 (00:00:00)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // 查询今日创建的挂单数量和接受的交易数量
        let offerCount = try await supabase
            .from("trade_offers")
            .select("id", head: false, count: .exact)
            .eq("seller_id", value: userId.uuidString)
            .gte("created_at", value: today.ISO8601Format())
            .lt("created_at", value: tomorrow.ISO8601Format())
            .execute()
            .count ?? 0

        let acceptCount = try await supabase
            .from("trade_history")
            .select("id", head: false, count: .exact)
            .eq("buyer_id", value: userId.uuidString)
            .gte("completed_at", value: today.ISO8601Format())
            .lt("completed_at", value: tomorrow.ISO8601Format())
            .execute()
            .count ?? 0

        let totalCount = offerCount + acceptCount
        todayTradeCount = totalCount

        logger.log("今日交易次数: \(totalCount) (挂单\(offerCount) + 接受\(acceptCount))", type: .info)

        return totalCount
    }

    /// 检查是否超过每日交易限制
    private func checkDailyTradeLimit() async throws {
        // 获取订阅限制
        let dailyLimit = SubscriptionManager.shared.dailyTradeLimit

        // 无限制（订阅用户）
        guard let limit = dailyLimit else {
            logger.log("订阅用户，交易无限制", type: .info)
            return
        }

        // 检查今日交易次数
        let count = try await getTodayTradeCount()

        if count >= limit {
            logger.log("已达到今日交易限制 (\(count)/\(limit))", type: .warning)
            throw TradeError.dailyLimitReached(limit: limit, current: count)
        }

        logger.log("交易次数检查通过 (\(count)/\(limit))", type: .info)
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// 添加测试挂单数据
    @discardableResult
    func addTestOffer() async -> Bool {
        guard AuthManager.shared.currentUser != nil else {
            logger.log("添加测试挂单失败：用户未登录", type: .error)
            return false
        }

        logger.log("创建测试挂单...", type: .info)

        // 确保有足够的物品
        _ = await inventoryManager.addTestResources()

        do {
            let offeringItems = [
                TradeItem(itemId: "wood", quantity: 10, quality: nil),
                TradeItem(itemId: "scrap_metal", quantity: 5, quality: nil)
            ]

            let requestingItems = [
                TradeItem(itemId: "bandage", quantity: 5, quality: .normal)
            ]

            _ = try await createOffer(
                offeringItems: offeringItems,
                requestingItems: requestingItems,
                message: "测试挂单"
            )

            logger.log("测试挂单创建成功", type: .success)
            return true

        } catch {
            logger.logError("创建测试挂单失败", error: error)
            return false
        }
    }
    #endif
}
