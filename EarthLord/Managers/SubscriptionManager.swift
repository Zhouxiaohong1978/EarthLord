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

        // 启动时检查所有当前有效授权，仅在 DB 无有效记录时补写（防止沙盒续费覆盖）
        Task { [weak self] in
            await self?.refreshSubscriptionStatus()
            // 只有 DB 查询后仍是 free，才尝试从 StoreKit 补写
            if await self?.currentTier == .free {
                await self?.syncCurrentEntitlements()
            }
        }
    }

    /// 将 StoreKit 当前有效授权补写到 DB
    /// 仅在 DB 无有效记录（currentTier==free）时调用，防止沙盒自动续费反复覆盖已有档位
    /// 只写入档位最高的那条授权，避免低档位覆盖高档位
    func syncCurrentEntitlements() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        // 找出 StoreKit 中档位最高的有效授权
        var highestTier: SubscriptionTier = .free
        var bestPair: (transaction: Transaction, product: Product)?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .autoRenewable,
                  let product = availableSubscriptions.first(where: { $0.id == transaction.productID }) else {
                continue
            }
            let tier = tierForProductId(product.id)
            if tier.rank > highestTier.rank {
                highestTier = tier
                bestPair = (transaction, product)
            }
        }

        guard let best = bestPair, highestTier != .free else {
            logger.log("syncCurrentEntitlements: StoreKit 无有效授权，跳过", type: .info)
            return
        }

        do {
            try await handleSubscription(transaction: best.transaction, product: best.product, userId: userId)
            logger.log("补写订阅记录成功: \(best.product.id)（\(highestTier.rawValue)）", type: .info)
            await refreshSubscriptionStatus()
        } catch {
            logger.logError("syncCurrentEntitlements 写库失败", error: error)
        }
    }

    /// 根据 product ID 推断订阅档位（用 basic/premium 区分，避免 earthlord 误匹配 lord）
    private func tierForProductId(_ id: String) -> SubscriptionTier {
        if id.contains("premium") { return .lord }
        if id.contains("basic") { return .explorer }
        return .free
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
            // 同时请求消耗型商品，用于诊断StoreKit是否正常工作
            let consumableIds = SupplyPackProduct.allCases.map { $0.rawValue }
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

    /// 登出时重置订阅状态，防止跨账号数据污染
    func resetForLogout() {
        currentTier = .free
        currentSubscription = nil
    }

    /// 刷新订阅状态
    func refreshSubscriptionStatus() async {
        // 记录查询时的用户 ID，防止异步结果写回时用户已切换
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

            // ⚠️ 异步查询完成后再次验证当前用户未切换，防止跨账号污染
            guard AuthManager.shared.currentUser?.id == userId,
                  AuthManager.shared.isAuthenticated else {
                logger.log("订阅结果已过期（用户已切换或登出），丢弃", type: .info)
                return
            }

            // 解析结果：必须 is_active = true 才算有效订阅
            let isActive = result["is_active"]?.boolValue ?? false
            if isActive,
               let tierString = result["tier"]?.stringValue,
               let tier = SubscriptionTier(rawValue: tierString),
               tier != .free {
                currentTier = tier
                await fetchSubscriptionDetails(userId: userId)
            } else {
                currentTier = .free
                currentSubscription = nil
            }

        } catch {
            logger.logError("查询订阅状态失败（保留当前档位 \(currentTier.rawValue)，不重置）", error: error)
            // 查询失败时不重置 currentTier，避免覆盖刚完成的购买结果
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

            // 写回前验证用户未切换
            guard AuthManager.shared.currentUser?.id == userId,
                  AuthManager.shared.isAuthenticated else { return }

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

                // 3. 处理订阅（写入数据库）
                try await handleSubscription(transaction: transaction, product: product, userId: userId)

                // 4. 完成交易
                await transaction.finish()

                // 5. 立即应用档位，不等待 DB 查询（防止 refreshSubscriptionStatus 因网络失败回退到 free）
                let immediteTier: SubscriptionTier
                if product.id.contains("basic") || product.id.contains("explorer") {
                    immediteTier = .explorer
                } else if product.id.contains("premium") || product.id.contains("lord") {
                    immediteTier = .lord
                } else {
                    immediteTier = .free
                }
                currentTier = immediteTier

                // 6. 后台从 DB 确认（失败时保留已设置的档位，不覆盖）
                Task { [weak self] in
                    await self?.refreshSubscriptionStatus()
                }

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
    /// StoreKit 2 中需要遍历 Transaction.currentEntitlements 重新写库，
    /// 仅 AppStore.sync() + refreshSubscriptionStatus() 无法恢复 DB 缺失的记录
    func restorePurchases() async throws {
        logger.log("开始恢复购买", type: .info)

        do {
            // 1. 强制同步 Apple 服务器最新购买记录
            try await AppStore.sync()

            // 2. 遍历所有当前有效授权，将 DB 里缺失的订阅补写进去
            guard let userId = AuthManager.shared.currentUser?.id else {
                throw SubscriptionError.notAuthenticated
            }

            var restoredCount = 0
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)

                    // 只处理订阅类型
                    guard transaction.productType == .autoRenewable else { continue }

                    // 找到对应的 Product 对象（可能 availableSubscriptions 还未加载）
                    let matchedProduct = availableSubscriptions.first(where: { $0.id == transaction.productID })
                    guard let product = matchedProduct else {
                        logger.log("恢复时找不到商品: \(transaction.productID)，跳过", type: .info)
                        continue
                    }

                    // 重新写库（handleSubscription 内部做 upsert，重复写安全）
                    try await handleSubscription(transaction: transaction, product: product, userId: userId)
                    restoredCount += 1
                    logger.log("已恢复交易: \(transaction.productID)", type: .success)

                } catch {
                    logger.logError("处理恢复交易失败: \(result)", error: error)
                }
            }

            logger.log("共恢复 \(restoredCount) 条交易记录", type: .info)

            // 3. 刷新订阅状态（现在 DB 应该有记录了）
            await refreshSubscriptionStatus()

            logger.log("恢复购买完成", type: .success)

        } catch let error as SubscriptionError {
            throw error
        } catch {
            logger.logError("恢复购买失败", error: error)
            throw SubscriptionError.subscribeFailed("恢复购买失败")
        }
    }

    // MARK: - 交易监听

    /// 监听交易更新
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self = self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // 自动处理订阅续费
                    await self.handleTransactionUpdate(transaction)

                    await transaction.finish()

                } catch {
                    self.logger.logError("交易更新处理失败", error: error)
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

    /// 每日探索次数限制（nil = 无限）
    var dailyExplorationLimit: Int? {
        currentTier.dailyExplorationLimit
    }

    /// 通讯范围倍率（叠加在建筑基础范围上）
    var communicationMultiplier: Double {
        currentTier.communicationMultiplier
    }

    /// 步行探索奖励倍率
    var walkRewardMultiplier: Double {
        currentTier.walkRewardMultiplier
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
