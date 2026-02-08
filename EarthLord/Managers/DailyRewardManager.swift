//
//  DailyRewardManager.swift
//  EarthLord
//
//  每日礼包管理器 - 管理订阅用户的每日奖励
//

import Foundation
import Supabase
import Combine

// MARK: - DailyRewardConfig

/// 每日礼包配置
struct DailyRewardConfig {
    let tier: SubscriptionTier
    let items: [RewardItem]

    struct RewardItem: Codable {
        let itemId: String
        let quantity: Int
        let quality: ItemQuality?
    }
}

// MARK: - DailyReward

/// 每日礼包领取记录
struct DailyReward: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let rewardDate: Date
    let tier: SubscriptionTier
    let items: [DailyRewardConfig.RewardItem]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rewardDate = "reward_date"
        case tier
        case items
        case createdAt = "created_at"
    }
}

// MARK: - DailyRewardError

/// 每日礼包错误
enum DailyRewardError: LocalizedError {
    case notAuthenticated
    case notSubscribed
    case alreadyClaimed
    case claimFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .notSubscribed:
            return "仅订阅用户可领取每日礼包"
        case .alreadyClaimed:
            return "今日礼包已领取"
        case .claimFailed(let message):
            return "领取失败: \(message)"
        }
    }
}

// MARK: - DailyRewardManager

/// 每日礼包管理器（单例）
@MainActor
final class DailyRewardManager: ObservableObject {

    // MARK: - Singleton

    static let shared = DailyRewardManager()

    // MARK: - Published Properties

    /// 是否已领取今日礼包
    @Published var hasClaimedToday: Bool = false

    /// 今日礼包内容
    @Published var todayReward: DailyRewardConfig?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 是否正在领取
    @Published var isClaiming: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private let logger = ExplorationLogger.shared

    // MARK: - Initialization

    private init() {
        logger.log("DailyRewardManager 初始化完成", type: .info)
    }

    // MARK: - 礼包配置

    /// 获取各档位的每日礼包配置
    private static let rewardConfigs: [SubscriptionTier: DailyRewardConfig] = [
        .explorer: DailyRewardConfig(
            tier: .explorer,
            items: [
                .init(itemId: "water_bottle", quantity: 3, quality: nil),        // 矿泉水 x3
                .init(itemId: "canned_food", quantity: 2, quality: .normal),     // 罐头食品 x2
                .init(itemId: "bandage", quantity: 2, quality: nil),             // 绷带 x2
                .init(itemId: "wood", quantity: 10, quality: nil),               // 木材 x10
                .init(itemId: "scrap_metal", quantity: 5, quality: nil)          // 废金属 x5
            ]
        ),

        .lord: DailyRewardConfig(
            tier: .lord,
            items: [
                .init(itemId: "water_bottle", quantity: 5, quality: nil),        // 矿泉水 x5
                .init(itemId: "canned_food", quantity: 3, quality: .good),       // 罐头食品 x3 (优质)
                .init(itemId: "bandage", quantity: 3, quality: nil),             // 绷带 x3
                .init(itemId: "wood", quantity: 20, quality: nil),               // 木材 x20
                .init(itemId: "scrap_metal", quantity: 15, quality: nil),        // 废金属 x15
                .init(itemId: "glass", quantity: 10, quality: nil),              // 玻璃 x10
                .init(itemId: "flashlight", quantity: 1, quality: .good)         // 手电筒 x1 (优质)
            ]
        )
    ]

    // MARK: - Public Methods

    /// 检查今日是否已领取
    func checkTodayStatus() async {
        guard AuthManager.shared.currentUser != nil else {
            hasClaimedToday = false
            return
        }

        // 防止重复检查（预加载 + 页面加载可能重叠）
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let claimed: Bool = try await supabase
                .rpc("check_daily_reward_claimed")
                .execute()
                .value

            hasClaimedToday = claimed

            // 更新今日礼包内容
            updateTodayReward()

            logger.log("今日礼包状态: \(claimed ? "已领取" : "可领取")", type: .info)

        } catch {
            logger.logError("检查礼包状态失败", error: error)
            hasClaimedToday = false
        }
    }

    /// 领取今日礼包
    func claimTodayReward() async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw DailyRewardError.notAuthenticated
        }

        // 检查订阅状态
        let currentTier = SubscriptionManager.shared.currentTier
        guard currentTier != .free else {
            throw DailyRewardError.notSubscribed
        }

        // 检查是否已领取
        if hasClaimedToday {
            throw DailyRewardError.alreadyClaimed
        }

        logger.log("领取每日礼包: \(currentTier.displayName)", type: .info)

        isClaiming = true
        defer { isClaiming = false }

        do {
            // 获取礼包配置
            guard let config = Self.rewardConfigs[currentTier] else {
                throw DailyRewardError.claimFailed("未找到礼包配置")
            }

            // 将物品添加到背包
            for item in config.items {
                try await InventoryManager.shared.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "每日礼包"
                )
            }

            // 记录到数据库
            try await saveRewardRecord(userId: userId, tier: currentTier, items: config.items)

            // 更新状态
            hasClaimedToday = true

            logger.log("每日礼包领取成功", type: .success)

        } catch {
            logger.logError("领取每日礼包失败", error: error)
            throw DailyRewardError.claimFailed(error.localizedDescription)
        }
    }

    /// 获取今日礼包预览
    func getTodayRewardPreview() -> DailyRewardConfig? {
        let currentTier = SubscriptionManager.shared.currentTier
        return Self.rewardConfigs[currentTier]
    }

    // MARK: - Private Methods

    /// 更新今日礼包内容（公开版本，供 View 调用）
    func updateTodayRewardPublic() {
        updateTodayReward()
    }

    /// 更新今日礼包内容
    private func updateTodayReward() {
        let currentTier = SubscriptionManager.shared.currentTier
        todayReward = Self.rewardConfigs[currentTier]
    }

    /// 保存领取记录到数据库
    private func saveRewardRecord(
        userId: UUID,
        tier: SubscriptionTier,
        items: [DailyRewardConfig.RewardItem]
    ) async throws {
        // 编码物品为 JSON
        let itemsData = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "itemId": item.itemId,
                "quantity": item.quantity
            ]
            if let quality = item.quality {
                dict["quality"] = quality.rawValue
            }
            return dict
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: itemsData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DailyRewardError.claimFailed("物品数据编码失败")
        }

        // 插入记录
        let rewardData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "reward_date": .string(ISO8601DateFormatter().string(from: Date())),
            "tier": .string(tier.rawValue),
            "items": .string(jsonString)
        ]

        try await supabase
            .from("daily_rewards")
            .insert(rewardData)
            .execute()

        logger.log("领取记录已保存", type: .success)
    }
}
