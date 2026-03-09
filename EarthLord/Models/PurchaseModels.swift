//
//  PurchaseModels.swift
//  EarthLord
//
//  内购系统数据模型
//

import Foundation
import StoreKit

// MARK: - 物资包产品定义

enum SupplyPackProduct: String, CaseIterable, Identifiable {
    case survivorPack    = "com.earthlord.survivor_pack"
    case constructorPack = "com.earthlord.constructor_pack"
    case engineerPack    = "com.earthlord.engineer_pack"
    case rarePack        = "com.earthlord.rare_pack"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .survivorPack:    return String(localized: "pack.survivor.name")
        case .constructorPack: return String(localized: "pack.constructor.name")
        case .engineerPack:    return String(localized: "pack.engineer.name")
        case .rarePack:        return String(localized: "pack.rare.name")
        }
    }

    var priceInCNY: Int {
        switch self {
        case .survivorPack:    return 6
        case .constructorPack: return 18
        case .engineerPack:    return 30
        case .rarePack:        return 68
        }
    }

    var iconName: String {
        switch self {
        case .survivorPack:    return "leaf.fill"
        case .constructorPack: return "hammer.fill"
        case .engineerPack:    return "wrench.and.screwdriver.fill"
        case .rarePack:        return "crown.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .survivorPack:    return "green"
        case .constructorPack: return "blue"
        case .engineerPack:    return "purple"
        case .rarePack:        return "orange"
        }
    }
}

// MARK: - 物资包物品

struct PackItem: Codable, Equatable {
    let itemId: String
    let quantity: Int
    let quality: String?
}

// MARK: - 物资包配置

struct SupplyPackConfig {
    let product: SupplyPackProduct
    let baseItems: [PackItem]
    let bonusItems: [BonusItem]

    struct BonusItem {
        let item: PackItem
        let probability: Int
    }
}

// MARK: - 物资包配置常量

extension SupplyPackConfig {
    static let all: [SupplyPackProduct: SupplyPackConfig] = [

        // ¥6 / $0.99 — 解决Tier1建造卡点
        .survivorPack: SupplyPackConfig(
            product: .survivorPack,
            baseItems: [
                PackItem(itemId: "wood",         quantity: 80,  quality: nil),
                PackItem(itemId: "stone",        quantity: 80,  quality: nil),
                PackItem(itemId: "canned_food",  quantity: 15,  quality: nil),
                PackItem(itemId: "water_bottle", quantity: 20,  quality: nil),
                PackItem(itemId: "bread",        quantity: 10,  quality: nil),
                PackItem(itemId: "bandage",      quantity: 8,   quality: nil)
            ],
            bonusItems: [
                BonusItem(item: PackItem(itemId: "cloth", quantity: 20, quality: nil), probability: 25)
            ]
        ),

        // ¥18 / $2.99 — 解决Tier1→2过渡缺金属/布料/工具
        .constructorPack: SupplyPackConfig(
            product: .constructorPack,
            baseItems: [
                PackItem(itemId: "scrap_metal",    quantity: 100, quality: nil),
                PackItem(itemId: "wood",           quantity: 60,  quality: nil),
                PackItem(itemId: "stone",          quantity: 50,  quality: nil),
                PackItem(itemId: "cloth",          quantity: 40,  quality: nil),
                PackItem(itemId: "tool",           quantity: 2,   quality: "good"),
                PackItem(itemId: "medicine",       quantity: 20,  quality: nil),
                PackItem(itemId: "build_speedup",  quantity: 5,   quality: nil)
            ],
            bonusItems: [
                BonusItem(item: PackItem(itemId: "electronic_component", quantity: 10, quality: nil), probability: 20)
            ]
        ),

        // ¥30 / $4.99 — 解决Tier2→3缺电子元件
        .engineerPack: SupplyPackConfig(
            product: .engineerPack,
            baseItems: [
                PackItem(itemId: "electronic_component", quantity: 20, quality: nil),
                PackItem(itemId: "scrap_metal",          quantity: 80, quality: nil),
                PackItem(itemId: "wood",                 quantity: 40, quality: nil),
                PackItem(itemId: "stone",                quantity: 30, quality: nil),
                PackItem(itemId: "build_speedup",        quantity: 10, quality: nil),
                PackItem(itemId: "tool",                 quantity: 3,  quality: "good")
            ],
            bonusItems: [
                BonusItem(item: PackItem(itemId: "antibiotics", quantity: 10, quality: nil), probability: 25),
                BonusItem(item: PackItem(itemId: "fuel",        quantity: 8,  quality: nil), probability: 25)
            ]
        ),

        // ¥68 / $9.99 — 解决Tier3高级建筑缺稀有材料
        .rarePack: SupplyPackConfig(
            product: .rarePack,
            baseItems: [
                PackItem(itemId: "electronic_component", quantity: 30, quality: nil),
                PackItem(itemId: "satellite_module",     quantity: 3,  quality: nil),
                PackItem(itemId: "fuel",                 quantity: 15, quality: nil),
                PackItem(itemId: "antibiotics",          quantity: 15, quality: nil),
                PackItem(itemId: "build_speedup",        quantity: 15, quality: nil)
            ],
            bonusItems: [
                BonusItem(item: PackItem(itemId: "equipment_rare",  quantity: 1, quality: "rare"),      probability: 30),
                BonusItem(item: PackItem(itemId: "blueprint_epic",  quantity: 1, quality: nil),          probability: 30),
                BonusItem(item: PackItem(itemId: "blueprint_basic", quantity: 2, quality: nil),          probability: 55)
            ]
        )
    ]
}

// MARK: - 物品名称本地化

extension String {
    var localizedItemName: String {
        switch self {
        case "water_bottle":          return String(localized: "item.water_bottle")
        case "canned_food":           return String(localized: "item.canned_food")
        case "bread":                 return String(localized: "item.bread")
        case "bandage":               return String(localized: "item.bandage")
        case "medicine":              return String(localized: "item.medicine")
        case "first_aid_kit":         return String(localized: "item.first_aid_kit")
        case "antibiotics":           return String(localized: "item.antibiotics")
        case "wood":                  return String(localized: "item.wood")
        case "stone":                 return String(localized: "item.stone")
        case "scrap_metal":           return String(localized: "item.scrap_metal")
        case "cloth":                 return String(localized: "item.cloth")
        case "seeds":                 return String(localized: "item.seeds")
        case "nails":                 return String(localized: "item.nails")
        case "glass":                 return String(localized: "item.glass")
        case "rope":                  return String(localized: "item.rope")
        case "flashlight":            return String(localized: "item.flashlight")
        case "tool":                  return String(localized: "item.tool")
        case "toolbox":               return String(localized: "item.toolbox")
        case "build_speedup":         return String(localized: "item.build_speedup")
        case "electronic_component":  return String(localized: "item.electronic_component")
        case "satellite_module":      return String(localized: "item.satellite_module")
        case "fuel":                  return String(localized: "item.fuel")
        case "scavenge_pass":         return String(localized: "item.scavenge_pass")
        case "blueprint_basic":       return String(localized: "item.blueprint_basic")
        case "blueprint_epic":        return String(localized: "item.blueprint_epic")
        case "equipment_rare":        return String(localized: "item.equipment_rare")
        case "equipment_epic":        return String(localized: "item.equipment_epic")
        default:                      return self
        }
    }

    var localizedQualityKey: String {
        switch self.lowercased() {
        case "broken":    return "quality.broken"
        case "worn":      return "quality.worn"
        case "normal":    return "quality.normal"
        case "good":      return "quality.good"
        case "excellent": return "quality.excellent"
        case "rare":      return "quality.rare"
        case "epic":      return "quality.epic"
        case "legendary": return "quality.legendary"
        default:          return self
        }
    }
}

// MARK: - 购买订单模型

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

enum PurchaseState {
    case idle
    case purchasing
    case success(productId: String)
    case failed(Error)
    case cancelled
}

// MARK: - 购买错误

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
            return String(localized: "error.purchase.not_authenticated")
        case .productNotFound:
            return String(localized: "error.purchase.product_not_found")
        case .purchaseFailed(let message):
            return "\(String(localized: "error.purchase.failed_prefix")): \(message)"
        case .verificationFailed:
            return String(localized: "error.purchase.verification_failed")
        case .deliveryFailed(let message):
            return "\(String(localized: "error.purchase.delivery_failed_prefix")): \(message)"
        case .invalidTransaction:
            return String(localized: "error.purchase.invalid_transaction")
        }
    }
}

// MARK: - 订阅商品枚举

enum SubscriptionProduct: String, CaseIterable, Identifiable {
    case explorerMonthly = "com.earthlord.sub.basic.monthly"
    case explorerYearly  = "com.earthlord.sub.basic.yearly"
    case lordMonthly     = "com.earthlord.sub.premium.monthly"
    case lordYearly      = "com.earthlord.sub.premium.yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explorerMonthly: return String(localized: "sub.explorer.monthly")
        case .explorerYearly:  return String(localized: "sub.explorer.yearly")
        case .lordMonthly:     return String(localized: "sub.lord.monthly")
        case .lordYearly:      return String(localized: "sub.lord.yearly")
        }
    }

    var shortName: String {
        switch self {
        case .explorerMonthly, .explorerYearly: return String(localized: "tier.explorer")
        case .lordMonthly, .lordYearly:         return String(localized: "tier.lord")
        }
    }

    var tier: SubscriptionTier {
        switch self {
        case .explorerMonthly, .explorerYearly: return .explorer
        case .lordMonthly, .lordYearly:         return .lord
        }
    }

    var isYearly: Bool {
        switch self {
        case .explorerYearly, .lordYearly: return true
        default: return false
        }
    }

    var savingsPercent: Int? {
        switch self {
        case .explorerYearly: return 39
        case .lordYearly:     return 44
        default:              return nil
        }
    }

    var durationInDays: Int { isYearly ? 365 : 30 }
}

// MARK: - 订阅档位

enum SubscriptionTier: String, Codable {
    case free     = "free"
    case explorer = "explorer"
    case lord     = "lord"

    var displayName: String {
        switch self {
        case .free:     return String(localized: "tier.free")
        case .explorer: return String(localized: "tier.explorer")
        case .lord:     return String(localized: "tier.lord")
        }
    }

    var badgeIcon: String {
        switch self {
        case .free:     return ""
        case .explorer: return "🥉"
        case .lord:     return "🥇"
        }
    }

    var callsignPrefix: String {
        switch self {
        case .free:     return ""
        case .explorer: return "[\(String(localized: "tier.explorer"))]"
        case .lord:     return "[\(String(localized: "tier.lord"))]"
        }
    }

    // MARK: 背包容量
    var backpackCapacity: Int {
        switch self {
        case .free:     return 100
        case .explorer: return 200
        case .lord:     return 300
        }
    }

    // MARK: 探索范围（km）
    var explorationRadius: Double {
        switch self {
        case .free:     return 1.0
        case .explorer: return 2.0
        case .lord:     return 3.0
        }
    }

    // MARK: POI搜刮冷却（小时）— 免费24h，探索者12h，领主6h
    var poiCooldownHours: Int {
        switch self {
        case .free:     return 24
        case .explorer: return 12
        case .lord:     return 6
        }
    }

    // MARK: 步行奖励倍率 — 免费1x，探索者1.5x，领主2x
    var walkRewardMultiplier: Double {
        switch self {
        case .free:     return 1.0
        case .explorer: return 1.5
        case .lord:     return 2.0
        }
    }

    // MARK: 建造速度倍率 — 仅领主有加成
    var buildSpeedMultiplier: Double {
        switch self {
        case .free:     return 1.0
        case .explorer: return 1.0
        case .lord:     return 2.0
        }
    }

    // MARK: 每日交易次数限制
    var dailyTradeLimit: Int? {
        switch self {
        case .free:     return 10
        case .explorer: return nil
        case .lord:     return nil
        }
    }

    // MARK: 每日庇护所收益
    var dailyHarvestLimit: Int? {
        switch self {
        case .free:     return 10
        case .explorer: return nil
        case .lord:     return nil
        }
    }

    // MARK: 每日礼包物品数量
    var dailyGiftCount: Int {
        switch self {
        case .free:     return 0
        case .explorer: return 5
        case .lord:     return 7
        }
    }
}

// MARK: - 用户订阅状态

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

    var isExpired: Bool { Date() > expiresAt }

    var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt)
        return max(0, components.day ?? 0)
    }
}

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

    func toUserSubscription() -> UserSubscription? {
        guard let id = id,
              let subscriptionId = UUID(uuidString: id),
              let userId = UUID(uuidString: userId),
              let tier = SubscriptionTier(rawValue: tier) else { return nil }
        let fmt = ISO8601DateFormatter()
        guard let purchaseDate = fmt.date(from: purchaseDate),
              let expiresAt = fmt.date(from: expiresAt) else { return nil }
        return UserSubscription(
            id: subscriptionId, userId: userId, productId: productId, tier: tier,
            transactionId: transactionId, originalTransactionId: originalTransactionId,
            purchaseDate: purchaseDate, expiresAt: expiresAt,
            isActive: isActive, autoRenew: autoRenew,
            createdAt: fmt.date(from: createdAt ?? "") ?? Date(),
            updatedAt: fmt.date(from: updatedAt ?? "") ?? Date()
        )
    }
}

// MARK: - 订阅状态 & 错误

enum SubscriptionStatus {
    case notSubscribed
    case active(tier: SubscriptionTier)
    case expired(tier: SubscriptionTier)
    case cancelled(tier: SubscriptionTier)
}

enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case productNotFound
    case subscribeFailed(String)
    case verificationFailed
    case alreadySubscribed
    case invalidSubscription

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return String(localized: "error.purchase.not_authenticated")
        case .productNotFound:    return String(localized: "error.purchase.product_not_found")
        case .subscribeFailed(let msg): return "\(String(localized: "error.sub.failed_prefix")): \(msg)"
        case .verificationFailed: return String(localized: "error.purchase.verification_failed")
        case .alreadySubscribed:  return String(localized: "error.sub.already_subscribed")
        case .invalidSubscription:return String(localized: "error.sub.invalid")
        }
    }
}
