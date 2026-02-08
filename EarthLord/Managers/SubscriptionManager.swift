//
//  SubscriptionManager.swift
//  EarthLord
//
//  订阅管理器 - 基于 StoreKit 2
//

import Foundation
import StoreKit
import Supabase
import Combine

// MARK: - SubscriptionManager

/// 订阅管理器（单例）
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    /// 可用订阅商品列表
    @Published var availableSubscriptions: [Product] = []

    /// 当前订阅状态
    @Published var currentSubscription: UserSubscription?

    /// 当前订阅档位
    @Published var currentTier: SubscriptionTier = .free

    /// 是否正在加载商品
    @Published var isLoadingProducts: Bool = false

    /// 是否正在订阅
    @Published var isSubscribing: Bool = false

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
        logger.log("SubscriptionManager 初始化完成", type: .info)
    }

    /// 启动交易监听（在首次加载商品后调用，避免 init 时触发 StoreKit 后台操作）
    func startTransactionListenerIfNeeded() {
        guard transactionListener == nil else { return }
        transactionListener = listenForTransactions()
        logger.log("交易监听已启动", type: .info)
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 商品加载

    /// 加载所有可用订阅商品
    func loadSubscriptions() async {
        // 已加载成功则跳过
        guard availableSubscriptions.isEmpty else { return }
        // 正在加载中则跳过（避免并发请求）
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            // 同时测试消耗型商品，诊断StoreKit是否完全不工作
            let consumableIds = ["com.earthlord.starter_pack", "com.earthlord.explorer_pack"]
            let allTestIds = productIds + consumableIds
            print("🛒 [StoreKit] 请求全部商品ID（订阅+消耗型）: \(allTestIds)")

            let allProducts = try await Product.products(for: allTestIds)
            print("🛒 [StoreKit] 返回 \(allProducts.count) 个商品:")
            for p in allProducts {
                print("   - \(p.id): \(p.displayName) (\(p.displayPrice)) type=\(p.type)")
            }

            // 只保留订阅商品
            let products = allProducts.filter { productIds.contains($0.id) }
            print("🛒 [StoreKit] 其中订阅商品: \(products.count) 个")

            self.availableSubscriptions = products.sorted { p1, p2 in
                // 按价格排序
                p1.price < p2.price
            }

            logger.log("成功加载 \(products.count) 个订阅商品", type: .success)

            // 延迟3秒启动交易监听，避免StoreKit后台任务与商品加载并发
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                startTransactionListenerIfNeeded()
            }
        } catch {
            print("🛒 [StoreKit] ❌ 加载失败: \(error)")
            logger.logError("加载订阅商品失败", error: error)
            errorMessage = "加载订阅商品失败: \(error.localizedDescription)"
        }
    }

    /// 根据产品ID获取商品
    func getProduct(for productId: String) -> Product? {
        availableSubscriptions.first { $0.id == productId }
    }

    // MARK: - 订阅状态查询

    /// 刷新订阅状态
    func refreshSubscriptionStatus() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            currentTier = .free
            return
        }

        do {
            // 调用 RPC 获取订阅状态
            let result: [String: AnyJSON] = try await supabase
                .rpc("get_current_subscription")
                .execute()
                .value

            logger.log("订阅状态查询结果: \(result)", type: .info)

            // 解析结果
            if let tierString = result["tier"]?.stringValue,
               let tier = SubscriptionTier(rawValue: tierString) {
                currentTier = tier

                // 如果是付费用户，获取完整订阅信息
                if tier != .free {
                    await fetchSubscriptionDetails(userId: userId)
                }
            } else {
                currentTier = .free
            }

        } catch {
            logger.logError("查询订阅状态失败", error: error)
            currentTier = .free
        }
    }

    /// 获取订阅详情
    private func fetchSubscriptionDetails(userId: UUID) async {
        do {
            let response: [SubscriptionDB] = try await supabase
                .from("user_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("expires_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let db = response.first,
               let subscription = db.toUserSubscription() {
                currentSubscription = subscription
                logger.log("订阅详情: \(subscription.tier.displayName)，到期: \(subscription.expiresAt)", type: .info)
            }
        } catch {
            logger.logError("获取订阅详情失败", error: error)
        }
    }

    // MARK: - 订阅购买

    /// 订阅商品
    func subscribe(_ product: Product) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw SubscriptionError.notAuthenticated
        }

        logger.log("开始订阅: \(product.displayName)", type: .info)

        isSubscribing = true
        defer { isSubscribing = false }

        do {
            // 1. 发起购买
            let result = try await product.purchase()

            // 2. 处理购买结果
            switch result {
            case .success(let verification):
                // 验证交易
                let transaction = try checkVerified(verification)

                // 3. 处理订阅
                try await handleSubscription(transaction: transaction, product: product, userId: userId)

                // 4. 完成交易
                await transaction.finish()

                // 5. 刷新订阅状态
                await refreshSubscriptionStatus()

                logger.log("订阅成功: \(product.displayName)", type: .success)

            case .userCancelled:
                logger.log("用户取消订阅", type: .info)
                throw SubscriptionError.subscribeFailed("用户取消")

            case .pending:
                logger.log("订阅等待中（需要家长批准）", type: .info)
                throw SubscriptionError.subscribeFailed("订阅需要批准")

            @unknown default:
                throw SubscriptionError.subscribeFailed("未知错误")
            }

        } catch {
            logger.logError("订阅失败", error: error)
            throw error
        }
    }

    /// 处理订阅交易
    private func handleSubscription(transaction: Transaction, product: Product, userId: UUID) async throws {
        logger.log("处理订阅交易: \(transaction.id)", type: .info)

        // 验证是订阅商品
        guard product.type == .autoRenewable else {
            throw SubscriptionError.invalidSubscription
        }

        // 确定订阅档位
        let tier: SubscriptionTier
        if product.id.contains("basic") || product.id.contains("explorer") {
            tier = .explorer
        } else if product.id.contains("premium") || product.id.contains("lord") {
            tier = .lord
        } else {
            tier = .free
        }

        // 计算到期时间
        let expirationDate: Date
        if let expiresDate = transaction.expirationDate {
            expirationDate = expiresDate
        } else {
            // 如果没有到期时间，根据商品类型计算
            let durationInDays = product.id.contains("yearly") ? 365 : 30
            expirationDate = Calendar.current.date(byAdding: .day, value: durationInDays, to: transaction.purchaseDate) ?? Date()
        }

        // 获取自动续费状态
        // 如果订阅被撤销（revocationDate 不为 nil），则 autoRenew 为 false
        let autoRenew = transaction.revocationDate == nil

        // 保存到数据库
        try await saveSubscriptionToDB(
            userId: userId,
            productId: product.id,
            tier: tier,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            purchaseDate: transaction.purchaseDate,
            expiresAt: expirationDate,
            autoRenew: autoRenew
        )
    }

    /// 保存订阅到数据库
    private func saveSubscriptionToDB(
        userId: UUID,
        productId: String,
        tier: SubscriptionTier,
        transactionId: String,
        originalTransactionId: String,
        purchaseDate: Date,
        expiresAt: Date,
        autoRenew: Bool
    ) async throws {
        let params: [String: AnyJSON] = [
            "p_product_id": .string(productId),
            "p_tier": .string(tier.rawValue),
            "p_transaction_id": .string(transactionId),
            "p_original_transaction_id": .string(originalTransactionId),
            "p_purchase_date": .string(ISO8601DateFormatter().string(from: purchaseDate)),
            "p_expires_at": .string(ISO8601DateFormatter().string(from: expiresAt)),
            "p_auto_renew": .bool(autoRenew)
        ]

        let result: [String: AnyJSON] = try await supabase
            .rpc("update_subscription", params: params)
            .execute()
            .value

        logger.log("订阅已保存到数据库: \(result)", type: .success)
    }

    // MARK: - 订阅管理

    /// 取消订阅（取消自动续费）
    func cancelSubscription() async throws {
        guard currentSubscription != nil else {
            throw SubscriptionError.notAuthenticated
        }

        logger.log("取消订阅自动续费", type: .info)

        do {
            let result: [String: AnyJSON] = try await supabase
                .rpc("cancel_subscription")
                .execute()
                .value

            logger.log("订阅已取消: \(result)", type: .success)

            // 刷新状态
            await refreshSubscriptionStatus()

        } catch {
            logger.logError("取消订阅失败", error: error)
            throw SubscriptionError.subscribeFailed(error.localizedDescription)
        }
    }

    /// 恢复购买
    func restorePurchases() async throws {
        logger.log("开始恢复购买", type: .info)

        do {
            // StoreKit 2 自动同步购买记录
            try await AppStore.sync()

            // 刷新订阅状态
            await refreshSubscriptionStatus()

            logger.log("恢复购买完成", type: .success)

        } catch {
            logger.logError("恢复购买失败", error: error)
            throw SubscriptionError.subscribeFailed("恢复购买失败")
        }
    }

    // MARK: - 交易监听

    /// 监听交易更新
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            guard let self = self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // 自动处理订阅续费
                    await self.handleTransactionUpdate(transaction)

                    await transaction.finish()

                } catch {
                    await self.logger.logError("交易更新处理失败", error: error)
                }
            }
        }
    }

    /// 处理交易更新（续费等）
    private func handleTransactionUpdate(_ transaction: Transaction) async {
        logger.log("处理交易更新: \(transaction.id)", type: .info)

        guard let userId = AuthManager.shared.currentUser?.id,
              let product = availableSubscriptions.first(where: { $0.id == transaction.productID }) else {
            return
        }

        do {
            try await handleSubscription(transaction: transaction, product: product, userId: userId)
            await refreshSubscriptionStatus()
        } catch {
            logger.logError("处理交易更新失败", error: error)
        }
    }

    // MARK: - 交易验证

    /// 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - 权益查询

    /// 获取背包容量
    var backpackCapacity: Int {
        currentTier.backpackCapacity
    }

    /// 获取探索范围
    var explorationRadius: Double {
        currentTier.explorationRadius
    }

    /// 获取建造速度倍率
    var buildSpeedMultiplier: Double {
        currentTier.buildSpeedMultiplier
    }

    /// 获取每日交易次数限制
    var dailyTradeLimit: Int? {
        currentTier.dailyTradeLimit
    }

    /// 获取每日庇护所收益限制
    var dailyHarvestLimit: Int? {
        currentTier.dailyHarvestLimit
    }

    /// 是否为订阅用户
    var isSubscribed: Bool {
        currentTier != .free
    }

    /// 订阅是否即将过期（7天内）
    var isExpiringSoon: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.daysRemaining <= 7 && subscription.daysRemaining > 0
    }

    /// 订阅是否已过期
    var isExpired: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.isExpired
    }

    /// 获取过期提示文本
    var expirationMessage: String? {
        guard let subscription = currentSubscription else { return nil }

        if subscription.isExpired {
            return "订阅已过期，部分功能受限"
        } else if isExpiringSoon {
            return "订阅将在\(subscription.daysRemaining)天后过期"
        }
        return nil
    }

    // MARK: - Expiration Handling

    /// 处理过期订阅（后台任务调用）
    func handleExpiredSubscriptions() async {
        do {
            let result: [String: AnyJSON] = try await supabase
                .rpc("expire_old_subscriptions")
                .execute()
                .value

            // 从 AnyJSON 中提取整数值
            if let expiredCountJSON = result["expired_count"],
               case .integer(let expiredCount) = expiredCountJSON {
                logger.log("已处理 \(expiredCount) 个过期订阅", type: .info)
            }

            // 刷新当前用户状态
            await refreshSubscriptionStatus()

        } catch {
            logger.logError("处理过期订阅失败", error: error)
        }
    }
}
