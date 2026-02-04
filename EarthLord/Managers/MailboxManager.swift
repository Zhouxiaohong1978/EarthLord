//
//  MailboxManager.swift
//  EarthLord
//
//  邮箱管理器
//

import Foundation
import Supabase
import Combine

// MARK: - MailboxManager

/// 邮箱管理器（单例）
@MainActor
final class MailboxManager: ObservableObject {

    // MARK: - Singleton

    static let shared = MailboxManager()

    // MARK: - Published Properties

    /// 邮件列表
    @Published var mails: [Mail] = []

    /// 未读邮件数量
    @Published var unreadCount: Int = 0

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

    /// 背包容量限制（临时，实际应从 InventoryManager 获取）
    private let backpackCapacity = 50

    // MARK: - Initialization

    private init() {
        logger.log("MailboxManager 初始化完成", type: .info)
    }

    // MARK: - 加载邮件

    /// 加载所有邮件
    func loadMails() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            logger.log("用户未登录，无法加载邮件", type: .error)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [MailDB] = try await supabase
                .from("mailbox")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let loadedMails = response.compactMap { $0.toMail() }

            await MainActor.run {
                self.mails = loadedMails
                self.unreadCount = loadedMails.filter { !$0.isRead && !$0.isClaimed }.count
            }

            logger.log("成功加载 \(loadedMails.count) 封邮件", type: .success)

        } catch {
            logger.logError("加载邮件失败", error: error)
            errorMessage = "加载邮件失败: \(error.localizedDescription)"
        }
    }

    /// 加载未读邮件数量
    func loadUnreadCount() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            return
        }

        do {
            // 直接查询未读邮件并计数
            let mails: [MailDB] = try await supabase
                .from("mailbox")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
                .value

            await MainActor.run {
                self.unreadCount = mails.count
            }

        } catch {
            logger.logError("加载未读数量失败", error: error)
        }
    }

    // MARK: - 邮件操作

    /// 标记邮件为已读
    func markAsRead(_ mail: Mail) async {
        guard !mail.isRead else { return }

        do {
            try await supabase
                .from("mailbox")
                .update(["is_read": true])
                .eq("id", value: mail.id.uuidString)
                .execute()

            // 更新本地状态
            if let index = mails.firstIndex(where: { $0.id == mail.id }) {
                mails[index].isRead = true
                unreadCount = max(0, unreadCount - 1)
            }

            logger.log("邮件已标记为已读", type: .info)

        } catch {
            logger.logError("标记已读失败", error: error)
        }
    }

    /// 领取邮件物品（部分领取机制）
    func claimMail(_ mail: Mail) async throws -> ClaimResult {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw PurchaseError.notAuthenticated
        }

        logger.log("开始领取邮件: \(mail.title)", type: .info)

        // 计算背包剩余空间
        let currentItemCount = InventoryManager.shared.items.reduce(0) { $0 + $1.quantity }
        let remainingSpace = max(0, backpackCapacity - currentItemCount)

        guard remainingSpace > 0 else {
            throw NSError(
                domain: "MailboxManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "背包已满，请先整理背包"]
            )
        }

        do {
            // 调用 RPC 函数部分领取
            let params: [String: AnyJSON] = [
                "p_mail_id": .string(mail.id.uuidString),
                "p_backpack_limit": .integer(remainingSpace)
            ]

            // RPC 返回 JSONB，直接解码为 ClaimResult
            let result: ClaimResult = try await supabase
                .rpc("claim_mail_partial", params: params)
                .execute()
                .value

            // 刷新邮件列表
            await loadMails()

            // 刷新背包
            await InventoryManager.shared.refreshInventory()

            logger.log("领取成功: 已领 \(result.claimedCount) 件，剩余 \(result.remainingCount) 件", type: .success)

            return result

        } catch {
            logger.logError("领取邮件失败", error: error)
            throw error
        }
    }

    /// 删除邮件
    func deleteMail(_ mail: Mail) async throws {
        do {
            try await supabase
                .from("mailbox")
                .delete()
                .eq("id", value: mail.id.uuidString)
                .execute()

            // 更新本地状态
            mails.removeAll { $0.id == mail.id }
            if !mail.isRead && !mail.isClaimed {
                unreadCount = max(0, unreadCount - 1)
            }

            logger.log("邮件已删除", type: .info)

        } catch {
            logger.logError("删除邮件失败", error: error)
            throw error
        }
    }

    /// 批量删除已领取的邮件
    func deleteClaimedMails() async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw PurchaseError.notAuthenticated
        }

        do {
            try await supabase
                .from("mailbox")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("is_claimed", value: true)
                .execute()

            // 刷新邮件列表
            await loadMails()

            logger.log("已删除所有已领取邮件", type: .success)

        } catch {
            logger.logError("批量删除失败", error: error)
            throw error
        }
    }

    // MARK: - 测试方法（开发用）

    #if DEBUG
    /// 发送测试邮件
    func sendTestMail() async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw PurchaseError.notAuthenticated
        }

        let testItems: [MailItem] = [
            MailItem(itemId: "water_001", quantity: 3, quality: nil),
            MailItem(itemId: "food_002", quantity: 2, quality: "normal")
        ]

        let itemsJSON = try JSONEncoder().encode(testItems)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"

        let params: [String: String] = [
            "p_user_id": userId.uuidString,
            "p_mail_type": "reward",
            "p_title": "测试邮件",
            "p_content": "这是一封测试邮件，包含一些测试物品。",
            "p_items": itemsString
        ]

        _ = try await supabase.rpc("send_mail", params: params).execute()

        await loadMails()

        logger.log("测试邮件已发送", type: .success)
    }
    #endif
}
