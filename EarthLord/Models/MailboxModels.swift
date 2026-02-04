//
//  MailboxModels.swift
//  EarthLord
//
//  邮箱系统数据模型
//

import Foundation

// MARK: - 邮件类型

/// 邮件类型枚举
enum MailType: String, Codable, CaseIterable {
    case purchase = "purchase"    // 购买物品
    case reward = "reward"        // 系统奖励
    case gift = "gift"            // 玩家赠送

    var displayName: String {
        switch self {
        case .purchase: return "购买物品"
        case .reward: return "系统奖励"
        case .gift: return "玩家赠送"
        }
    }

    var iconName: String {
        switch self {
        case .purchase: return "bag.fill"
        case .reward: return "gift.fill"
        case .gift: return "heart.fill"
        }
    }
}

// MARK: - 邮件物品

/// 邮件中的物品
struct MailItem: Codable, Identifiable, Equatable {
    let itemId: String
    let quantity: Int
    let quality: String?

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
        case quality
    }
}

// MARK: - 邮件模型

/// 邮件（本地模型）
struct Mail: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let mailType: MailType
    let title: String
    let content: String?
    var items: [MailItem]
    var isRead: Bool
    var isClaimed: Bool
    var claimedAt: Date?
    let expiresAt: Date?
    let purchaseId: UUID?
    let createdAt: Date
    let updatedAt: Date

    /// 是否已过期
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 剩余天数
    var daysRemaining: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
        return max(0, days ?? 0)
    }

    /// 物品总数
    var totalItemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", mailType = "mail_type"
        case title, content, items
        case isRead = "is_read", isClaimed = "is_claimed"
        case claimedAt = "claimed_at", expiresAt = "expires_at"
        case purchaseId = "purchase_id"
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

// MARK: - 邮件数据库模型

/// 邮件数据库模型
struct MailDB: Codable {
    let id: String
    let userId: String
    let mailType: String
    let title: String
    let content: String?
    let items: [MailItem]  // JSONB 数组
    let isRead: Bool?
    let isClaimed: Bool?
    let claimedAt: String?
    let expiresAt: String?
    let purchaseId: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", mailType = "mail_type"
        case title, content, items
        case isRead = "is_read", isClaimed = "is_claimed"
        case claimedAt = "claimed_at", expiresAt = "expires_at"
        case purchaseId = "purchase_id"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    /// 转换为本地模型
    func toMail() -> Mail? {
        guard let id = UUID(uuidString: id),
              let userId = UUID(uuidString: userId),
              let mailType = MailType(rawValue: mailType) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return Mail(
            id: id,
            userId: userId,
            mailType: mailType,
            title: title,
            content: content,
            items: items,
            isRead: isRead ?? false,
            isClaimed: isClaimed ?? false,
            claimedAt: claimedAt.flatMap { formatter.date(from: $0) },
            expiresAt: expiresAt.flatMap { formatter.date(from: $0) },
            purchaseId: purchaseId.flatMap { UUID(uuidString: $0) },
            createdAt: createdAt.flatMap { formatter.date(from: $0) } ?? Date(),
            updatedAt: updatedAt.flatMap { formatter.date(from: $0) } ?? Date()
        )
    }
}

// MARK: - 领取结果

/// 领取邮件结果
struct ClaimResult: Codable {
    let claimedItems: [MailItem]
    let remainingItems: [MailItem]
    let claimedCount: Int
    let remainingCount: Int
    let spaceUsed: Int

    enum CodingKeys: String, CodingKey {
        case claimedItems = "claimed_items"
        case remainingItems = "remaining_items"
        case claimedCount = "claimed_count"
        case remainingCount = "remaining_count"
        case spaceUsed = "space_used"
    }

    /// 是否全部领取
    var isFullyClaimed: Bool {
        remainingItems.isEmpty
    }
}
