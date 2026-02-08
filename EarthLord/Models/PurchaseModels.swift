//
//  PurchaseModels.swift
//  EarthLord
//
//  内购系统数据模型
//

import Foundation
import StoreKit

// MARK: - 物资包产品定义

/// 物资包产品枚举
enum SupplyPackProduct: String, CaseIterable, Identifiable {
    case starterPack = "com.earthlord.starter_pack"
    case explorerPack = "com.earthlord.explorer_pack"
    case builderPack = "com.earthlord.builder_pack"
    case premiumPack = "com.earthlord.premium_pack"

    var id: String { rawValue }

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .starterPack: return "新手物资包"
        case .explorerPack: return "探索物资包"
        case .builderPack: return "建设物资包"
        case .premiumPack: return "高级物资包"
        }
    }

    /// 商品描述
    var description: String {
        switch self {
        case .starterPack:
            return "包含矿泉水×5、罐头食品×3、绷带×2"
        case .explorerPack:
            return "包含手电筒×1、绳子×2、矿泉水×3、高级搜刮券×1"
        case .builderPack:
            return "包含木材×20、废金属×15、玻璃×10、建筑加速令×2"
        case .premiumPack:
            return "包含稀有装备×1、传奇物品×1、各类资源若干、背包扩容×10"
        }
    }

    /// 参考价格（人民币）
    var priceInCNY: Int {
        switch self {
        case .starterPack: return 6
        case .explorerPack: return 12
        case .builderPack: return 18
        case .premiumPack: return 30
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .starterPack: return "gift.fill"
        case .explorerPack: return "map.fill"
        case .builderPack: return "hammer.fill"
        case .premiumPack: return "crown.fill"
        }
    }

    /// 图标颜色
    var iconColor: String {
        switch self {
        case .starterPack: return "green"
        case .explorerPack: return "blue"
        case .builderPack: return "orange"
        case .premiumPack: return "purple"
        }
    }
}

// MARK: - 物资包内容配置

/// 物资包物品
struct PackItem: Codable, Equatable {
    let itemId: String
    let quantity: Int
    let quality: String?  // ItemQuality 的字符串形式
}

/// 物资包内容配置
struct SupplyPackConfig {
    let product: SupplyPackProduct
    let baseItems: [PackItem]
    let bonusItems: [BonusItem]

    struct BonusItem {
        let item: PackItem
        let probability: Int  // 概率（1-100）
    }
}

// MARK: - 物资包配置常量

extension SupplyPackConfig {
    /// 所有物资包配置
    static let all: [SupplyPackProduct: SupplyPackConfig] = [
        .starterPack: SupplyPackConfig(
            product: .starterPack,
            baseItems: [
                PackItem(itemId: "water_bottle", quantity: 5, quality: nil),
                PackItem(itemId: "canned_food", quantity: 3, quality: "normal"),
                PackItem(itemId: "bandage", quantity: 2, quality: nil)
            ],
            bonusItems: []
        ),

        .explorerPack: SupplyPackConfig(
            product: .explorerPack,
            baseItems: [
                PackItem(itemId: "flashlight", quantity: 1, quality: "good"),
                PackItem(itemId: "rope", quantity: 2, quality: nil),
                PackItem(itemId: "water_bottle", quantity: 3, quality: nil)
            ],
            bonusItems: [
                BonusItem(
                    item: PackItem(itemId: "flashlight", quantity: 1, quality: "legendary"),
                    probability: 10
                )
            ]
        ),

        .builderPack: SupplyPackConfig(
            product: .builderPack,
            baseItems: [
                PackItem(itemId: "wood", quantity: 20, quality: nil),
                PackItem(itemId: "scrap_metal", quantity: 15, quality: nil),
                PackItem(itemId: "glass", quantity: 10, quality: nil)
            ],
            bonusItems: [
                BonusItem(
                    item: PackItem(itemId: "consumable_build_speedup", quantity: 3, quality: nil),
                    probability: 15
                )
            ]
        ),

        .premiumPack: SupplyPackConfig(
            product: .premiumPack,
            baseItems: [
                PackItem(itemId: "equipment_rare", quantity: 1, quality: "rare"),
                PackItem(itemId: "wood", quantity: 10, quality: nil),
                PackItem(itemId: "scrap_metal", quantity: 10, quality: nil),
                PackItem(itemId: "water_bottle", quantity: 5, quality: nil),
                PackItem(itemId: "canned_food", quantity: 5, quality: nil)
            ],
            bonusItems: [
                BonusItem(
                    item: PackItem(itemId: "equipment_legendary", quantity: 1, quality: "legendary"),
                    probability: 20
                )
            ]
        )
    ]
}

// MARK: - 购买订单模型

/// 购买订单（本地模型）
struct Purchase: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let productId: String
    let transactionId: String
    let originalTransactionId: String?
    let purchaseDate: Date
    let quantity: Int
    let price: Decimal?
    let currency: String
    let environment: String
    var isDelivered: Bool
    var deliveredAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case quantity, price, currency, environment
        case isDelivered = "is_delivered"
        case deliveredAt = "delivered_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 购买订单数据库模型
struct PurchaseDB: Codable {
    let id: String?
    let userId: String
    let productId: String
    let transactionId: String
    let originalTransactionId: String?
    let purchaseDate: String
    let quantity: Int
    let price: String?
    let currency: String
    let environment: String
    let isDelivered: Bool
    let deliveredAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case quantity, price, currency, environment
        case isDelivered = "is_delivered"
        case deliveredAt = "delivered_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 购买状态

/// 购买状态
enum PurchaseState {
    case idle
    case purchasing
    case success(productId: String)
    case failed(Error)
    case cancelled
}

// MARK: - 购买错误

/// 购买错误类型
enum PurchaseError: LocalizedError {
    case notAuthenticated
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed
    case deliveryFailed(String)
    case invalidTransaction

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .productNotFound:
            return "商品不存在"
        case .purchaseFailed(let message):
            return "购买失败: \(message)"
        case .verificationFailed:
            return "交易验证失败"
        case .deliveryFailed(let message):
            return "发货失败: \(message)"
        case .invalidTransaction:
            return "无效的交易"
        }
    }
}

// MARK: - 订阅系统模型

/// 订阅商品枚举
enum SubscriptionProduct: String, CaseIterable, Identifiable {
    // 探索者（基础版）
    case explorerMonthly = "com.earthlord.sub.basic.monthly"
    case explorerYearly = "com.earthlord.sub.basic.yearly"

    // 领主（高级版）
    case lordMonthly = "com.earthlord.sub.premium.monthly"
    case lordYearly = "com.earthlord.sub.premium.yearly"

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .explorerMonthly: return "探索者·月卡"
        case .explorerYearly: return "探索者·年卡"
        case .lordMonthly: return "领主·月卡"
        case .lordYearly: return "领主·年卡"
        }
    }

    /// 简短名称
    var shortName: String {
        switch self {
        case .explorerMonthly, .explorerYearly: return "探索者"
        case .lordMonthly, .lordYearly: return "领主"
        }
    }

    /// 价格（人民币）
    var price: Int {
        switch self {
        case .explorerMonthly: return 12
        case .explorerYearly: return 88
        case .lordMonthly: return 25
        case .lordYearly: return 168
        }
    }

    /// 月均价格
    var monthlyEquivalent: Double {
        switch self {
        case .explorerMonthly: return 12.0
        case .explorerYearly: return 7.3
        case .lordMonthly: return 25.0
        case .lordYearly: return 14.0
        }
    }

    /// 优惠百分比（仅年卡）
    var savingsPercent: Int? {
        switch self {
        case .explorerYearly: return 39
        case .lordYearly: return 44
        default: return nil
        }
    }

    /// 订阅档位
    var tier: SubscriptionTier {
        switch self {
        case .explorerMonthly, .explorerYearly: return .explorer
        case .lordMonthly, .lordYearly: return .lord
        }
    }

    /// 是否为年卡
    var isYearly: Bool {
        switch self {
        case .explorerYearly, .lordYearly: return true
        default: return false
        }
    }

    /// 订阅周期（天数）
    var durationInDays: Int {
        isYearly ? 365 : 30
    }
}

/// 订阅档位
enum SubscriptionTier: String, Codable {
    case free = "free"           // 幸存者（免费）
    case explorer = "explorer"   // 探索者（基础版）
    case lord = "lord"          // 领主（高级版）

    /// 显示名称
    var displayName: String {
        switch self {
        case .free: return "幸存者"
        case .explorer: return "探索者"
        case .lord: return "领主"
        }
    }

    /// 徽章图标
    var badgeIcon: String {
        switch self {
        case .free: return ""
        case .explorer: return "🥉"
        case .lord: return "🥇"
        }
    }

    /// 呼号前缀
    var callsignPrefix: String {
        switch self {
        case .free: return ""
        case .explorer: return "[探索者]"
        case .lord: return "[领主]"
        }
    }

    /// 背包容量
    var backpackCapacity: Int {
        switch self {
        case .free: return 100
        case .explorer: return 200
        case .lord: return 300
        }
    }

    /// 探索范围（km）
    var explorationRadius: Double {
        switch self {
        case .free: return 1.0
        case .explorer: return 2.0
        case .lord: return 3.0
        }
    }

    /// 建造速度倍率
    var buildSpeedMultiplier: Double {
        switch self {
        case .free: return 1.0
        case .explorer: return 2.0
        case .lord: return 2.0
        }
    }

    /// 每日交易次数限制（nil表示无限）
    var dailyTradeLimit: Int? {
        switch self {
        case .free: return 10
        case .explorer: return nil
        case .lord: return nil
        }
    }

    /// 每日庇护所收益次数限制（nil表示无限）
    var dailyHarvestLimit: Int? {
        switch self {
        case .free: return 10
        case .explorer: return nil
        case .lord: return nil
        }
    }
}

/// 用户订阅状态（本地模型）
struct UserSubscription: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let productId: String
    let tier: SubscriptionTier
    let transactionId: String
    let originalTransactionId: String?
    let purchaseDate: Date
    let expiresAt: Date
    var isActive: Bool
    var autoRenew: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case tier
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case autoRenew = "auto_renew"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 剩余天数
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiresAt)
        return max(0, components.day ?? 0)
    }
}

/// 用户订阅数据库模型
struct SubscriptionDB: Codable {
    let id: String?
    let userId: String
    let productId: String
    let tier: String
    let transactionId: String
    let originalTransactionId: String?
    let purchaseDate: String
    let expiresAt: String
    let isActive: Bool
    let autoRenew: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case tier
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case autoRenew = "auto_renew"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为本地模型
    func toUserSubscription() -> UserSubscription? {
        guard let id = id,
              let subscriptionId = UUID(uuidString: id),
              let userId = UUID(uuidString: userId),
              let tier = SubscriptionTier(rawValue: tier) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        guard let purchaseDate = dateFormatter.date(from: purchaseDate),
              let expiresAt = dateFormatter.date(from: expiresAt) else {
            return nil
        }

        let createdDate = createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedDate = updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()

        return UserSubscription(
            id: subscriptionId,
            userId: userId,
            productId: productId,
            tier: tier,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId,
            purchaseDate: purchaseDate,
            expiresAt: expiresAt,
            isActive: isActive,
            autoRenew: autoRenew,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

/// 订阅状态
enum SubscriptionStatus {
    case notSubscribed              // 未订阅
    case active(tier: SubscriptionTier)  // 订阅中
    case expired(tier: SubscriptionTier) // 已过期
    case cancelled(tier: SubscriptionTier) // 已取消
}

/// 订阅错误
enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case productNotFound
    case subscribeFailed(String)
    case verificationFailed
    case alreadySubscribed
    case invalidSubscription

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .productNotFound:
            return "订阅商品不存在"
        case .subscribeFailed(let message):
            return "订阅失败: \(message)"
        case .verificationFailed:
            return "订阅验证失败"
        case .alreadySubscribed:
            return "您已经订阅了此服务"
        case .invalidSubscription:
            return "无效的订阅"
        }
    }
}
