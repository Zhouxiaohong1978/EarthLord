//
//  DailyTaskManager.swift
//  EarthLord
//
//  每日任务管理器 - 自动检测进度，复用 MailboxManager.deliverItems 发放奖励
//

import Foundation
import Supabase

// MARK: - DailyTaskType

enum DailyTaskType: String, CaseIterable, Identifiable {
    case explore     = "explore"
    case communicate = "communicate"
    case territory   = "territory"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore:     return String(localized: "今日探索")
        case .communicate: return String(localized: "今日通讯")
        case .territory:   return String(localized: "今日圈地")
        }
    }

    var taskDescription: String {
        switch self {
        case .explore:     return String(localized: "完成一次探索（行走 ≥ 200 米）")
        case .communicate: return String(localized: "在任意频道发送 1 条消息")
        case .territory:   return String(localized: "成功圈占 1 块新领地")
        }
    }

    var icon: String {
        switch self {
        case .explore:     return "figure.walk"
        case .communicate: return "bubble.left.fill"
        case .territory:   return "flag.fill"
        }
    }

    var rewardItems: [MailItem] {
        let r = WeeklyRewardRotation.current
        switch self {
        case .explore:     return r.exploreItems
        case .communicate: return r.communicateItems
        case .territory:   return r.territoryItems
        }
    }

    var rewardDescription: String {
        let r = WeeklyRewardRotation.current
        switch self {
        case .explore:     return r.exploreDesc
        case .communicate: return r.communicateDesc
        case .territory:   return r.territoryDesc
        }
    }
}

// MARK: - WeeklyRewardRotation

/// 每周奖励轮换（4周循环，对应 T1→T2→T2/T3→T3 建造主题，每种物品1-2件）
struct WeeklyRewardRotation {
    let theme: String
    let exploreItems: [MailItem];     let exploreDesc: String
    let communicateItems: [MailItem]; let communicateDesc: String
    let territoryItems: [MailItem];   let territoryDesc: String

    static let all: [WeeklyRewardRotation] = [

        // Week 0 — T1 基础建造（篝火/帐篷/医疗站核心材料）
        .init(
            theme: "T1 基础建造",
            exploreItems: [
                MailItem(itemId: "wood",  quantity: 2, quality: nil),
                MailItem(itemId: "stone", quantity: 1, quality: nil)
            ], exploreDesc: "木材×2 + 石头×1",
            communicateItems: [
                MailItem(itemId: "cloth",   quantity: 2, quality: nil),
                MailItem(itemId: "bandage", quantity: 1, quality: nil)
            ], communicateDesc: "布料×2 + 绷带×1",
            territoryItems: [
                MailItem(itemId: "scrap_metal", quantity: 2, quality: nil),
                MailItem(itemId: "rope",        quantity: 1, quality: nil)
            ], territoryDesc: "废金属×2 + 绳子×1"
        ),

        // Week 1 — T2 扩展建造（净水装置/小仓库/瞭望台核心材料）
        .init(
            theme: "T2 扩展建造",
            exploreItems: [
                MailItem(itemId: "scrap_metal", quantity: 2, quality: nil),
                MailItem(itemId: "stone",       quantity: 2, quality: nil)
            ], exploreDesc: "废金属×2 + 石头×2",
            communicateItems: [
                MailItem(itemId: "rope",  quantity: 1, quality: nil),
                MailItem(itemId: "cloth", quantity: 2, quality: nil)
            ], communicateDesc: "绳子×1 + 布料×2",
            territoryItems: [
                MailItem(itemId: "wood",        quantity: 2, quality: nil),
                MailItem(itemId: "scrap_metal", quantity: 1, quality: nil)
            ], territoryDesc: "木材×2 + 废金属×1"
        ),

        // Week 2 — T2/T3 过渡（发电机棚/燃料储备站/中仓库核心材料）
        .init(
            theme: "T2/T3 过渡",
            exploreItems: [
                MailItem(itemId: "scrap_metal", quantity: 2, quality: nil),
                MailItem(itemId: "fuel",        quantity: 1, quality: nil)
            ], exploreDesc: "废金属×2 + 燃料×1",
            communicateItems: [
                MailItem(itemId: "stone", quantity: 2, quality: nil),
                MailItem(itemId: "rope",  quantity: 1, quality: nil)
            ], communicateDesc: "石头×2 + 绳子×1",
            territoryItems: [
                MailItem(itemId: "wood",  quantity: 2, quality: nil),
                MailItem(itemId: "cloth", quantity: 1, quality: nil)
            ], territoryDesc: "木材×2 + 布料×1"
        ),

        // Week 3 — T3 终局精英（太阳能板/电台/领主旗台核心材料）
        .init(
            theme: "T3 终局精英",
            exploreItems: [
                MailItem(itemId: "scrap_metal",          quantity: 2, quality: nil),
                MailItem(itemId: "electronic_component", quantity: 1, quality: nil)
            ], exploreDesc: "废金属×2 + 电子元件×1",
            communicateItems: [
                MailItem(itemId: "cloth", quantity: 2, quality: nil),
                MailItem(itemId: "stone", quantity: 2, quality: nil)
            ], communicateDesc: "布料×2 + 石头×2",
            territoryItems: [
                MailItem(itemId: "wood",        quantity: 2, quality: nil),
                MailItem(itemId: "scrap_metal", quantity: 2, quality: nil)
            ], territoryDesc: "木材×2 + 废金属×2"
        )
    ]

    /// 当前周轮换（ISO weekOfYear % 4）
    static var current: WeeklyRewardRotation {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return all[week % all.count]
    }
}

// MARK: - DailyTask

struct DailyTask: Identifiable {
    var id = UUID()
    let type: DailyTaskType
    var isCompleted: Bool
    var isRewardClaimed: Bool

    var canClaim: Bool { isCompleted && !isRewardClaimed }
}

// MARK: - DailyTaskError

enum DailyTaskError: LocalizedError {
    case notAuthenticated
    case taskNotCompleted
    case alreadyClaimed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return String(localized: "用户未登录")
        case .taskNotCompleted: return String(localized: "任务尚未完成")
        case .alreadyClaimed:   return String(localized: "奖励已领取")
        }
    }
}

// MARK: - DailyTaskManager

@MainActor
final class DailyTaskManager: ObservableObject {

    static let shared = DailyTaskManager()

    @Published var tasks: [DailyTask] = DailyTaskType.allCases.map {
        DailyTask(type: $0, isCompleted: false, isRewardClaimed: false)
    }
    @Published var isLoading = false
    @Published var claimError: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Refresh

    /// 刷新今日任务进度（并发查询三张现有表）
    func refresh() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let since = todayStartISO()

            async let exploreOk     = checkExplore(userId: userId, since: since)
            async let communicateOk = checkCommunicate(userId: userId, since: since)
            async let territoryOk   = checkTerritory(userId: userId, since: since)
            async let claimed       = loadClaimedTypes(userId: userId)

            let (e, c, t, cl) = try await (exploreOk, communicateOk, territoryOk, claimed)

            tasks = [
                DailyTask(type: .explore,     isCompleted: e, isRewardClaimed: cl.contains("explore")),
                DailyTask(type: .communicate, isCompleted: c, isRewardClaimed: cl.contains("communicate")),
                DailyTask(type: .territory,   isCompleted: t, isRewardClaimed: cl.contains("territory"))
            ]
        } catch {
            print("⚠️ [DailyTask] refresh 失败: \(error)")
        }
    }

    // MARK: - Claim Reward

    /// 领取单项任务奖励，复用 MailboxManager.deliverItems
    func claimReward(for task: DailyTask) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw DailyTaskError.notAuthenticated
        }
        guard task.isCompleted  else { throw DailyTaskError.taskNotCompleted }
        guard !task.isRewardClaimed else { throw DailyTaskError.alreadyClaimed }

        // 1. 写入领取记录（UNIQUE 约束防重复领取）
        struct Insert: Encodable {
            let user_id: String
            let task_date: String
            let task_type: String
        }
        try await supabase
            .from("daily_task_rewards")
            .insert(Insert(user_id: userId.uuidString,
                           task_date: todayDateStr(),
                           task_type: task.type.rawValue))
            .execute()

        // 2. 复用 MailboxManager.deliverItems 发放奖励邮件
        try await MailboxManager.shared.deliverItems(
            to: userId,
            mailType: .reward,
            title: String(format: String(localized: "每日任务奖励：%@"), task.type.title),
            content: String(format: String(localized: "完成【%@】，获得：%@"), task.type.title, task.type.rewardDescription),
            items: task.type.rewardItems,
            expiresInDays: 3
        )

        // 3. 更新本地状态
        if let idx = tasks.firstIndex(where: { $0.type == task.type }) {
            tasks[idx].isRewardClaimed = true
        }

        // 4. 触发本地通知
        NotificationManager.shared.sendTaskRewardNotification(taskTitle: task.type.title)
    }

    // MARK: - Private Queries

    private func checkExplore(userId: UUID, since: String) async throws -> Bool {
        struct Row: Codable { let id: String }
        let rows: [Row] = try await supabase
            .from("exploration_sessions")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("started_at", value: since)
            .gte("distance_walked", value: 200)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }

    private func checkCommunicate(userId: UUID, since: String) async throws -> Bool {
        struct Row: Codable { let message_id: String }
        let rows: [Row] = try await supabase
            .from("channel_messages")
            .select("message_id")
            .eq("sender_id", value: userId.uuidString)
            .gte("created_at", value: since)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }

    private func checkTerritory(userId: UUID, since: String) async throws -> Bool {
        struct Row: Codable { let id: String }
        let rows: [Row] = try await supabase
            .from("territories")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .gte("created_at", value: since)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }

    private func loadClaimedTypes(userId: UUID) async throws -> Set<String> {
        struct Row: Codable { let task_type: String }
        let rows: [Row] = try await supabase
            .from("daily_task_rewards")
            .select("task_type")
            .eq("user_id", value: userId.uuidString)
            .eq("task_date", value: todayDateStr())
            .execute().value
        return Set(rows.map(\.task_type))
    }

    // MARK: - Helpers

    private func todayStartISO() -> String {
        let start = Calendar.current.startOfDay(for: Date())
        return ISO8601DateFormatter().string(from: start)
    }

    private func todayDateStr() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
