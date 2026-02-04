//
//  PurchaseManager.swift
//  EarthLord
//
//  内购管理器 - 基于 StoreKit 2
//

import Foundation
import StoreKit
import Supabase
import Combine

// MARK: - PurchaseManager

/// 内购管理器（单例）
@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Published Properties

    /// 可用商品列表
    @Published var availableProducts: [Product] = []

    /// 购买状态
    @Published var purchaseState: PurchaseState = .idle

    /// 是否正在加载商品
    @Published var isLoadingProducts: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 交易监听任务
    private var transactionListener: Task<Void, Never>?

    /// 日志器
    private let logger = ExplorationLogger.shared

    // MARK: - Initialization

    private init() {
        // 启动交易监听
        transactionListener = listenForTransactions()
        logger.log("PurchaseManager 初始化完成", type: .info)
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 商品加载

    /// 加载所有可用商品
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let productIds = SupplyPackProduct.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIds)

            await MainActor.run {
                self.availableProducts = products.sorted { p1, p2 in
                    // 按价格排序
                    p1.price < p2.price
                }
            }

            logger.log("成功加载 \(products.count) 个商品", type: .success)
        } catch {
            logger.logError("加载商品失败", error: error)
            errorMessage = "加载商品失败: \(error.localizedDescription)"
        }
    }

    /// 根据产品ID获取商品
    func getProduct(for productId: String) -> Product? {
        availableProducts.first { $0.id == productId }
    }

    // MARK: - 购买流程

    /// 购买商品
    func purchase(_ product: Product) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw PurchaseError.notAuthenticated
        }

        logger.log("开始购买: \(product.displayName)", type: .info)
        await MainActor.run {
            purchaseState = .purchasing
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // 发货
                try await deliverPurchase(transaction)

                // 完成交易
                await transaction.finish()

                await MainActor.run {
                    purchaseState = .success(productId: product.id)
                }

                logger.log("购买成功: \(product.displayName)", type: .success)

            case .userCancelled:
                await MainActor.run {
                    purchaseState = .cancelled
                }
                logger.log("用户取消购买", type: .info)

            case .pending:
                await MainActor.run {
                    purchaseState = .idle
                }
                logger.log("购买待处理（等待家长批准）", type: .info)

            @unknown default:
                throw PurchaseError.purchaseFailed("未知购买结果")
            }

        } catch {
            await MainActor.run {
                purchaseState = .failed(error)
                errorMessage = error.localizedDescription
            }
            logger.logError("购买失败", error: error)
            throw error
        }
    }

    // MARK: - 交易验证

    /// 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - 发货逻辑

    /// 发货（保存订单 + 发送邮件）
    private func deliverPurchase(_ transaction: Transaction) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw PurchaseError.notAuthenticated
        }

        logger.log("开始发货: \(transaction.productID)", type: .info)

        // 1. 保存购买订单
        let purchaseId = try await savePurchaseRecord(transaction, userId: userId)

        // 2. 生成物品（保底 + 随机奖励）
        let items = generateItems(for: transaction.productID)

        // 3. 发送邮件
        try await sendMailWithItems(
            userId: userId,
            productId: transaction.productID,
            items: items,
            purchaseId: purchaseId
        )

        // 4. 标记已发货
        try await markAsDelivered(purchaseId: purchaseId)

        logger.log("发货完成: \(transaction.productID)", type: .success)
    }

    /// 保存购买订单到数据库
    private func savePurchaseRecord(_ transaction: Transaction, userId: UUID) async throws -> UUID {
        struct PurchaseInsert: Encodable {
            let user_id: String
            let product_id: String
            let transaction_id: String
            let original_transaction_id: String
            let purchase_date: String
            let quantity: Int
            let environment: String
        }

        let purchaseData = PurchaseInsert(
            user_id: userId.uuidString,
            product_id: transaction.productID,
            transaction_id: String(transaction.id),
            original_transaction_id: String(transaction.originalID),
            purchase_date: ISO8601DateFormatter().string(from: transaction.purchaseDate),
            quantity: 1,
            environment: transaction.environment == .production ? "Production" : "Sandbox"
        )

        struct PurchaseResponse: Codable {
            let id: String
        }

        let response: [PurchaseResponse] = try await supabase
            .from("purchases")
            .insert(purchaseData)
            .select()
            .execute()
            .value

        guard let purchaseId = response.first?.id,
              let uuid = UUID(uuidString: purchaseId) else {
            throw PurchaseError.deliveryFailed("保存订单失败")
        }

        return uuid
    }

    /// 生成物品（保底 + 随机）
    private func generateItems(for productId: String) -> [MailItem] {
        guard let product = SupplyPackProduct(rawValue: productId),
              let config = SupplyPackConfig.all[product] else {
            logger.log("未找到产品配置: \(productId)", type: .error)
            return []
        }

        var items: [MailItem] = config.baseItems.map {
            MailItem(itemId: $0.itemId, quantity: $0.quantity, quality: $0.quality)
        }

        // 随机奖励
        for bonus in config.bonusItems {
            let random = Int.random(in: 1...100)
            if random <= bonus.probability {
                items.append(MailItem(
                    itemId: bonus.item.itemId,
                    quantity: bonus.item.quantity,
                    quality: bonus.item.quality
                ))
                logger.log("触发随机奖励: \(bonus.item.itemId) (概率 \(bonus.probability)%)", type: .info)
            }
        }

        return items
    }

    /// 发送邮件
    private func sendMailWithItems(
        userId: UUID,
        productId: String,
        items: [MailItem],
        purchaseId: UUID
    ) async throws {
        let productName = SupplyPackProduct(rawValue: productId)?.displayName ?? "物资包"

        let itemsJSON = try JSONEncoder().encode(items)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"

        let params: [String: String] = [
            "p_user_id": userId.uuidString,
            "p_mail_type": "purchase",
            "p_title": "您购买的\(productName)已送达",
            "p_content": "感谢您的购买！物品已发送到邮箱，请查收。",
            "p_items": itemsString,
            "p_purchase_id": purchaseId.uuidString
        ]

        _ = try await supabase.rpc("send_mail", params: params).execute()
        logger.log("邮件发送成功", type: .success)
    }

    /// 标记订单已发货
    private func markAsDelivered(purchaseId: UUID) async throws {
        struct UpdateDelivered: Encodable {
            let is_delivered: Bool
            let delivered_at: String
        }

        let updateData = UpdateDelivered(
            is_delivered: true,
            delivered_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("purchases")
            .update(updateData)
            .eq("id", value: purchaseId.uuidString)
            .execute()
    }

    // MARK: - 交易监听

    /// 监听未完成的交易
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                do {
                    let transaction = try await self.checkVerified(result)

                    // 如果交易未完成，尝试发货
                    await self.handleUnfinishedTransaction(transaction)

                } catch {
                    await MainActor.run {
                        self.logger.logError("处理交易失败", error: error)
                    }
                }
            }
        }
    }

    /// 处理未完成的交易
    private func handleUnfinishedTransaction(_ transaction: Transaction) async {
        guard AuthManager.shared.currentUser != nil else {
            return
        }

        do {
            // 检查是否已发货
            let existing: [PurchaseDB] = try await supabase
                .from("purchases")
                .select()
                .eq("transaction_id", value: String(transaction.id))
                .execute()
                .value

            if existing.isEmpty {
                // 首次处理，执行发货
                try await deliverPurchase(transaction)
            }

            // 完成交易
            await transaction.finish()

        } catch {
            logger.logError("处理未完成交易失败", error: error)
        }
    }

    // MARK: - 恢复购买

    /// 恢复购买（处理所有未完成的交易）
    func restorePurchases() async {
        logger.log("开始恢复购买", type: .info)

        do {
            try await AppStore.sync()
            logger.log("购买恢复完成", type: .success)
        } catch {
            logger.logError("恢复购买失败", error: error)
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }
    }
}
