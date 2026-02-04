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
                PackItem(itemId: "water_001", quantity: 5, quality: nil),
                PackItem(itemId: "food_002", quantity: 3, quality: "normal"),
                PackItem(itemId: "medical_001", quantity: 2, quality: nil)
            ],
            bonusItems: []
        ),

        .explorerPack: SupplyPackConfig(
            product: .explorerPack,
            baseItems: [
                PackItem(itemId: "tool_flashlight", quantity: 1, quality: "good"),
                PackItem(itemId: "tool_rope", quantity: 2, quality: nil),
                PackItem(itemId: "water_001", quantity: 3, quality: nil)
            ],
            bonusItems: [
                BonusItem(
                    item: PackItem(itemId: "tool_flashlight", quantity: 1, quality: "legendary"),
                    probability: 10
                )
            ]
        ),

        .builderPack: SupplyPackConfig(
            product: .builderPack,
            baseItems: [
                PackItem(itemId: "material_wood", quantity: 20, quality: nil),
                PackItem(itemId: "material_metal", quantity: 15, quality: nil),
                PackItem(itemId: "material_glass", quantity: 10, quality: nil)
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
                PackItem(itemId: "material_wood", quantity: 10, quality: nil),
                PackItem(itemId: "material_metal", quantity: 10, quality: nil),
                PackItem(itemId: "water_001", quantity: 5, quality: nil),
                PackItem(itemId: "food_002", quantity: 5, quality: nil)
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
