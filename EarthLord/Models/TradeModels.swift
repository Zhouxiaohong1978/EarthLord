//
//  TradeModels.swift
//  EarthLord
//
//  交易系统数据模型
//  包含：交易状态、交易物品、挂单、交易历史、错误类型
//

import Foundation
import SwiftUI

// MARK: - TradeOfferStatus 交易状态

/// 交易挂单状态枚举
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"           // 挂单中
    case completed = "completed"     // 已完成
    case cancelled = "cancelled"     // 已取消
    case expired = "expired"         // 已过期

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .active:
            return String(localized: "挂单中")
        case .completed:
            return String(localized: "已完成")
        case .cancelled:
            return String(localized: "已取消")
        case .expired:
            return String(localized: "已过期")
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .active:
            return ApocalypseTheme.success
        case .completed:
            return ApocalypseTheme.info
        case .cancelled:
            return .gray
        case .expired:
            return ApocalypseTheme.warning
        }
    }

    /// 状态图标
    var icon: String {
        switch self {
        case .active:
            return "arrow.left.arrow.right.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .expired:
            return "clock.badge.exclamationmark.fill"
        }
    }
}

// MARK: - TradeItem 交易物品

/// 交易物品模型
/// 代表一笔交易中涉及的单个物品
struct TradeItem: Codable, Identifiable, Equatable {
    let id: UUID
    let itemId: String           // 关联 BackpackItem.itemId
    let quantity: Int            // 数量
    let quality: ItemQuality?    // 品质（可选）

    init(
        id: UUID = UUID(),
        itemId: String,
        quantity: Int,
        quality: ItemQuality? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
    }

    /// 获取物品名称（从物品定义表）
    var itemName: String {
        MockExplorationData.getItemDefinition(by: itemId)?.name ?? itemId
    }

    /// 显示文本
    var displayText: String {
        var text = "\(itemName) x\(quantity)"
        if let quality = quality {
            text += " (\(quality.rawValue))"
        }
        return text
    }
}

// MARK: - TradeExchange 交易交换详情

/// 交易交换详情
/// 记录一笔完成交易中双方交换的物品
struct TradeExchange: Codable, Equatable {
    let sellerItems: [TradeItem]   // 卖家提供的物品
    let buyerItems: [TradeItem]    // 买家提供的物品

    init(sellerItems: [TradeItem], buyerItems: [TradeItem]) {
        self.sellerItems = sellerItems
        self.buyerItems = buyerItems
    }
}

// MARK: - TradeOffer 交易挂单

/// 交易挂单模型
/// 代表一个待交易的挂单
struct TradeOffer: Identifiable, Codable, Equatable {
    let id: UUID
    let ownerId: UUID                    // 挂单者用户ID
    let ownerUsername: String            // 挂单者用户名
    let offeringItems: [TradeItem]       // 出售物品列表
    let requestingItems: [TradeItem]     // 求购物品列表
    var status: TradeOfferStatus         // 挂单状态
    let message: String?                 // 留言
    let createdAt: Date                  // 创建时间
    let expiresAt: Date                  // 过期时间
    var completedAt: Date?               // 完成时间
    var completedByUserId: UUID?         // 接单者ID
    var completedByUsername: String?     // 接单者用户名

    init(
        id: UUID = UUID(),
        ownerId: UUID,
        ownerUsername: String,
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        status: TradeOfferStatus = .active,
        message: String? = nil,
        createdAt: Date = Date(),
        expiresAt: Date,
        completedAt: Date? = nil,
        completedByUserId: UUID? = nil,
        completedByUsername: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.ownerUsername = ownerUsername
        self.offeringItems = offeringItems
        self.requestingItems = requestingItems
        self.status = status
        self.message = message
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.completedAt = completedAt
        self.completedByUserId = completedByUserId
        self.completedByUsername = completedByUsername
    }

    // MARK: - 计算属性

    /// 检查是否已过期
    var isExpired: Bool {
        return Date() > expiresAt && status == .active
    }

    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        let remaining = expiresAt.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// 格式化的剩余时间
    var formattedRemainingTime: String {
        let remaining = remainingTime
        guard remaining > 0 else { return String(localized: "已过期") }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return String(localized: "即将过期")
        }
    }

    /// 出售物品摘要
    var offeringSummary: String {
        offeringItems.map { $0.displayText }.joined(separator: ", ")
    }

    /// 求购物品摘要
    var requestingSummary: String {
        requestingItems.map { $0.displayText }.joined(separator: ", ")
    }
}

// MARK: - TradeHistory 交易历史

/// 交易历史模型
/// 记录已完成的交易详情
struct TradeHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let offerId: UUID                    // 关联挂单ID
    let sellerId: UUID                   // 卖家ID（挂单创建者）
    let buyerId: UUID                    // 买家ID（接单者）
    let sellerUsername: String           // 卖家用户名
    let buyerUsername: String            // 买家用户名
    let itemsExchanged: TradeExchange    // 交换物品详情
    let completedAt: Date                // 完成时间
    var sellerRating: Int?               // 卖家对买家的评分 (1-5)
    var buyerRating: Int?                // 买家对卖家的评分 (1-5)
    var sellerComment: String?           // 卖家评论
    var buyerComment: String?            // 买家评论

    init(
        id: UUID = UUID(),
        offerId: UUID,
        sellerId: UUID,
        buyerId: UUID,
        sellerUsername: String,
        buyerUsername: String,
        itemsExchanged: TradeExchange,
        completedAt: Date = Date(),
        sellerRating: Int? = nil,
        buyerRating: Int? = nil,
        sellerComment: String? = nil,
        buyerComment: String? = nil
    ) {
        self.id = id
        self.offerId = offerId
        self.sellerId = sellerId
        self.buyerId = buyerId
        self.sellerUsername = sellerUsername
        self.buyerUsername = buyerUsername
        self.itemsExchanged = itemsExchanged
        self.completedAt = completedAt
        self.sellerRating = sellerRating
        self.buyerRating = buyerRating
        self.sellerComment = sellerComment
        self.buyerComment = buyerComment
    }

    // MARK: - 计算属性

    /// 格式化完成时间
    var formattedCompletedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: completedAt)
    }

    /// 检查指定用户是否为卖家
    func isSeller(userId: UUID) -> Bool {
        return sellerId == userId
    }

    /// 检查指定用户是否为买家
    func isBuyer(userId: UUID) -> Bool {
        return buyerId == userId
    }

    /// 检查指定用户是否已评价
    func hasRated(userId: UUID) -> Bool {
        if isSeller(userId: userId) {
            return sellerRating != nil
        } else if isBuyer(userId: userId) {
            return buyerRating != nil
        }
        return false
    }
}

// MARK: - TradeOfferDB Supabase 数据库模型

/// 交易挂单数据库模型（用于 Supabase）
struct TradeOfferDB: Codable {
    let id: String?
    let ownerId: String
    let ownerUsername: String
    let offeringItems: String          // JSON 字符串
    let requestingItems: String        // JSON 字符串
    let status: String
    let message: String?
    let createdAt: String?
    let expiresAt: String
    let completedAt: String?
    let completedByUserId: String?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 转换为 TradeOffer
    func toTradeOffer() -> TradeOffer? {
        guard let idString = id,
              let id = UUID(uuidString: idString),
              let ownerId = UUID(uuidString: ownerId),
              let status = TradeOfferStatus(rawValue: status) else {
            return nil
        }

        // 解析 JSON 字符串
        let decoder = JSONDecoder()
        guard let offeringData = offeringItems.data(using: .utf8),
              let requestingData = requestingItems.data(using: .utf8),
              let offering = try? decoder.decode([TradeItem].self, from: offeringData),
              let requesting = try? decoder.decode([TradeItem].self, from: requestingData) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let created = createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let expires = dateFormatter.date(from: expiresAt) ?? Date().addingTimeInterval(86400)
        let completed = completedAt.flatMap { dateFormatter.date(from: $0) }
        let completedBy = completedByUserId.flatMap { UUID(uuidString: $0) }

        return TradeOffer(
            id: id,
            ownerId: ownerId,
            ownerUsername: ownerUsername,
            offeringItems: offering,
            requestingItems: requesting,
            status: status,
            message: message,
            createdAt: created,
            expiresAt: expires,
            completedAt: completed,
            completedByUserId: completedBy,
            completedByUsername: completedByUsername
        )
    }
}

// MARK: - TradeHistoryDB Supabase 数据库模型

/// 交易历史数据库模型（用于 Supabase）
struct TradeHistoryDB: Codable {
    let id: String?
    let offerId: String
    let sellerId: String
    let buyerId: String
    let sellerUsername: String
    let buyerUsername: String
    let itemsExchanged: String         // JSON 字符串
    let completedAt: String
    let sellerRating: Int?
    let buyerRating: Int?
    let sellerComment: String?
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case sellerUsername = "seller_username"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 转换为 TradeHistory
    func toTradeHistory() -> TradeHistory? {
        guard let idString = id,
              let id = UUID(uuidString: idString),
              let offerId = UUID(uuidString: offerId),
              let sellerId = UUID(uuidString: sellerId),
              let buyerId = UUID(uuidString: buyerId) else {
            return nil
        }

        // 解析 JSON 字符串
        let decoder = JSONDecoder()
        guard let exchangeData = itemsExchanged.data(using: .utf8),
              let exchange = try? decoder.decode(TradeExchange.self, from: exchangeData) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let completed = dateFormatter.date(from: completedAt) ?? Date()

        return TradeHistory(
            id: id,
            offerId: offerId,
            sellerId: sellerId,
            buyerId: buyerId,
            sellerUsername: sellerUsername,
            buyerUsername: buyerUsername,
            itemsExchanged: exchange,
            completedAt: completed,
            sellerRating: sellerRating,
            buyerRating: buyerRating,
            sellerComment: sellerComment,
            buyerComment: buyerComment
        )
    }
}

// MARK: - TradeError 错误类型

/// 交易操作错误类型
enum TradeError: LocalizedError {
    case notAuthenticated               // 未登录
    case offerNotFound                  // 挂单不存在
    case insufficientItems([String: Int])  // 物品不足
    case invalidStatus                  // 状态无效
    case cannotAcceptOwnOffer           // 不能接受自己的挂单
    case offerExpired                   // 已过期
    case alreadyCompleted               // 已完成
    case notParticipant                 // 非参与者
    case alreadyRated                   // 已评价
    case saveFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "用户未登录")
        case .offerNotFound:
            return String(localized: "挂单不存在")
        case .insufficientItems(let missing):
            let itemList = missing.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            return String(format: String(localized: "物品不足，还需要: %@"), itemList)
        case .invalidStatus:
            return String(localized: "挂单状态无效")
        case .cannotAcceptOwnOffer:
            return String(localized: "不能接受自己的挂单")
        case .offerExpired:
            return String(localized: "挂单已过期")
        case .alreadyCompleted:
            return String(localized: "交易已完成")
        case .notParticipant:
            return String(localized: "您不是该交易的参与者")
        case .alreadyRated:
            return String(localized: "您已经评价过该交易")
        case .saveFailed(let message):
            return String(format: String(localized: "保存失败: %@"), message)
        case .loadFailed(let message):
            return String(format: String(localized: "加载失败: %@"), message)
        }
    }
}

// MARK: - CanAcceptTradeResult 交易检查结果

/// 交易检查结果
struct CanAcceptTradeResult {
    let canAccept: Bool
    let missingItems: [String: Int]
    let error: TradeError?

    /// 成功结果
    static func success() -> CanAcceptTradeResult {
        return CanAcceptTradeResult(canAccept: true, missingItems: [:], error: nil)
    }

    /// 物品不足结果
    static func insufficientItems(_ missing: [String: Int]) -> CanAcceptTradeResult {
        return CanAcceptTradeResult(canAccept: false, missingItems: missing, error: .insufficientItems(missing))
    }

    /// 错误结果
    static func error(_ error: TradeError) -> CanAcceptTradeResult {
        return CanAcceptTradeResult(canAccept: false, missingItems: [:], error: error)
    }
}

// MARK: - AcceptTradeRPCResult RPC 结果模型

/// 接受交易 RPC 函数的 JSONB 返回结果
struct AcceptTradeRPCResult: Codable {
    let success: Bool
    let error: String?
    let message: String?
    let historyId: String?
    let offerId: String?
    let sellerId: String?
    let buyerId: String?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case historyId = "history_id"
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case completedAt = "completed_at"
    }
}

// MARK: - AcceptTradeRPCResponse RPC 响应模型（旧版）

/// 接受交易 RPC 函数的响应模型
struct AcceptTradeRPCResponse: Codable {
    let success: Bool
    let error: String?
    let message: String?
    let historyId: UUID?
    let offerId: UUID?
    let sellerId: UUID?
    let buyerId: UUID?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case historyId = "history_id"
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case completedAt = "completed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        // UUID 解析
        if let historyIdString = try container.decodeIfPresent(String.self, forKey: .historyId) {
            historyId = UUID(uuidString: historyIdString)
        } else {
            historyId = nil
        }

        if let offerIdString = try container.decodeIfPresent(String.self, forKey: .offerId) {
            offerId = UUID(uuidString: offerIdString)
        } else {
            offerId = nil
        }

        if let sellerIdString = try container.decodeIfPresent(String.self, forKey: .sellerId) {
            sellerId = UUID(uuidString: sellerIdString)
        } else {
            sellerId = nil
        }

        if let buyerIdString = try container.decodeIfPresent(String.self, forKey: .buyerId) {
            buyerId = UUID(uuidString: buyerIdString)
        } else {
            buyerId = nil
        }

        // 日期解析
        if let completedAtString = try container.decodeIfPresent(String.self, forKey: .completedAt) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            completedAt = dateFormatter.date(from: completedAtString)
        } else {
            completedAt = nil
        }
    }

    /// 转换错误码为 TradeError
    func toTradeError() -> TradeError? {
        guard !success, let errorCode = error else { return nil }

        switch errorCode {
        case "offer_not_found":
            return .offerNotFound
        case "invalid_status":
            return .invalidStatus
        case "offer_expired":
            return .offerExpired
        case "cannot_accept_own_offer":
            return .cannotAcceptOwnOffer
        case "transaction_failed":
            return .saveFailed(message ?? "事务执行失败")
        default:
            return .saveFailed(message ?? errorCode)
        }
    }
}
