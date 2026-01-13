//
//  ExplorationStatsManager.swift
//  EarthLord
//
//  探索统计管理器 - 管理用户探索统计数据（累计距离、排名、历史记录）
//

import Foundation
import Supabase
import Combine

// MARK: - ExplorationStats

/// 探索统计数据
struct ExplorationStats {
    /// 累计行走距离（米）
    let totalDistance: Double

    /// 探索次数
    let explorationCount: Int

    /// 累计探索时长（秒）
    let totalDuration: Int

    /// 距离排名
    let distanceRank: Int

    /// 最高单次距离
    let maxSingleDistance: Double

    /// 格式化的累计距离
    var formattedTotalDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f 公里", totalDistance / 1000)
        } else {
            return String(format: "%.0f 米", totalDistance)
        }
    }

    /// 格式化的累计时长
    var formattedTotalDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - ExplorationHistoryItem

/// 探索历史记录项
struct ExplorationHistoryItem: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let distance: Double
    let duration: Int
    let status: String
    let rewardTier: String?

    /// 格式化的距离
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 格式化的时长
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return "\(minutes)分\(seconds)秒"
    }

    /// 格式化的日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: startTime)
    }
}

// MARK: - ExplorationStatsManager

/// 探索统计管理器（单例）
@MainActor
final class ExplorationStatsManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = ExplorationStatsManager()

    // MARK: - Published Properties

    /// 当前用户的统计数据
    @Published var stats: ExplorationStats?

    /// 探索历史记录
    @Published var history: [ExplorationHistoryItem] = []

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

    /// 缓存的统计数据
    private var cachedStats: ExplorationStats?
    private var cacheTime: Date?
    private let cacheValidDuration: TimeInterval = 60 // 缓存有效期60秒

    // MARK: - Initialization

    private init() {
        logger.log("ExplorationStatsManager 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 获取用户累计行走距离
    /// - Returns: 累计距离（米）
    func getTotalDistance() async throws -> Double {
        let stats = try await getStats()
        return stats.totalDistance
    }

    /// 获取用户距离排名
    /// - Returns: 排名（从1开始）
    func getUserRank() async throws -> Int {
        let stats = try await getStats()
        return stats.distanceRank
    }

    /// 获取完整的探索统计数据
    /// - Parameter forceRefresh: 是否强制刷新（忽略缓存）
    /// - Returns: 探索统计数据
    func getStats(forceRefresh: Bool = false) async throws -> ExplorationStats {
        // 检查缓存
        if !forceRefresh,
           let cached = cachedStats,
           let time = cacheTime,
           Date().timeIntervalSince(time) < cacheValidDuration {
            return cached
        }

        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.log("开始加载探索统计数据...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. 获取用户的探索记录统计
            let userStats = try await fetchUserStats(userId: userId)

            // 2. 计算排名
            let rank = try await calculateRank(userId: userId, totalDistance: userStats.totalDistance)

            let stats = ExplorationStats(
                totalDistance: userStats.totalDistance,
                explorationCount: userStats.count,
                totalDuration: userStats.totalDuration,
                distanceRank: rank,
                maxSingleDistance: userStats.maxDistance
            )

            // 更新缓存
            cachedStats = stats
            cacheTime = Date()
            self.stats = stats

            logger.log(
                String(format: "统计数据加载完成: 累计%.1fm, 排名#%d, %d次探索",
                       stats.totalDistance, stats.distanceRank, stats.explorationCount),
                type: .success
            )

            return stats

        } catch {
            logger.logError("加载统计数据失败", error: error)
            throw error
        }
    }

    /// 刷新统计数据（供 UI 调用）
    func refreshStats() async {
        do {
            _ = try await getStats(forceRefresh: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 获取探索历史记录
    /// - Parameter limit: 最大返回条数
    /// - Returns: 历史记录列表
    func getExplorationHistory(limit: Int = 20) async throws -> [ExplorationHistoryItem] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.log("开始加载探索历史...", type: .info)

        // 定义返回数据结构
        struct SessionRecord: Codable {
            let id: String
            let startedAt: String
            let endedAt: String
            let distanceWalked: Double
            let durationSeconds: Int
            let status: String
            let rewardTier: String?

            enum CodingKeys: String, CodingKey {
                case id
                case startedAt = "started_at"
                case endedAt = "ended_at"
                case distanceWalked = "distance_walked"
                case durationSeconds = "duration_seconds"
                case status
                case rewardTier = "reward_tier"
            }
        }

        let response: [SessionRecord] = try await supabase
            .from("exploration_sessions")
            .select("id, started_at, ended_at, distance_walked, duration_seconds, status, reward_tier")
            .eq("user_id", value: userId.uuidString)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let dateFormatter = ISO8601DateFormatter()

        let historyItems = response.compactMap { record -> ExplorationHistoryItem? in
            guard let startTime = dateFormatter.date(from: record.startedAt),
                  let endTime = dateFormatter.date(from: record.endedAt) else {
                return nil
            }

            return ExplorationHistoryItem(
                id: UUID(uuidString: record.id) ?? UUID(),
                startTime: startTime,
                endTime: endTime,
                distance: record.distanceWalked,
                duration: record.durationSeconds,
                status: record.status,
                rewardTier: record.rewardTier
            )
        }

        self.history = historyItems
        logger.log("加载了 \(historyItems.count) 条探索历史", type: .success)

        return historyItems
    }

    /// 清除缓存
    func clearCache() {
        cachedStats = nil
        cacheTime = nil
        logger.log("统计缓存已清除", type: .info)
    }

    // MARK: - Private Methods

    /// 用户统计数据结构
    private struct UserStatsResult {
        let totalDistance: Double
        let count: Int
        let totalDuration: Int
        let maxDistance: Double
    }

    /// 获取用户的探索统计
    private func fetchUserStats(userId: UUID) async throws -> UserStatsResult {
        // 定义返回数据结构
        struct StatsRecord: Codable {
            let distanceWalked: Double
            let durationSeconds: Int

            enum CodingKeys: String, CodingKey {
                case distanceWalked = "distance_walked"
                case durationSeconds = "duration_seconds"
            }
        }

        let response: [StatsRecord] = try await supabase
            .from("exploration_sessions")
            .select("distance_walked, duration_seconds")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .execute()
            .value

        let totalDistance = response.reduce(0) { $0 + $1.distanceWalked }
        let totalDuration = response.reduce(0) { $0 + $1.durationSeconds }
        let maxDistance = response.map { $0.distanceWalked }.max() ?? 0

        return UserStatsResult(
            totalDistance: totalDistance,
            count: response.count,
            totalDuration: totalDuration,
            maxDistance: maxDistance
        )
    }

    /// 计算用户排名
    private func calculateRank(userId: UUID, totalDistance: Double) async throws -> Int {
        // 使用 SQL 查询统计比当前用户累计距离更多的用户数量
        // 排名 = 比自己距离多的人数 + 1

        struct RankResult: Codable {
            let userId: String
            let totalDistance: Double

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case totalDistance = "total_distance"
            }
        }

        // 查询所有用户的累计距离
        // 由于 Supabase 的聚合查询限制，我们需要用 RPC 或手动计算
        // 这里使用简化方案：查询所有已完成的探索记录，按用户分组计算

        struct SessionRecord: Codable {
            let userId: String
            let distanceWalked: Double

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case distanceWalked = "distance_walked"
            }
        }

        let allSessions: [SessionRecord] = try await supabase
            .from("exploration_sessions")
            .select("user_id, distance_walked")
            .eq("status", value: "completed")
            .execute()
            .value

        // 按用户分组计算累计距离
        var userDistances: [String: Double] = [:]
        for session in allSessions {
            userDistances[session.userId, default: 0] += session.distanceWalked
        }

        // 计算排名（比当前用户距离多的人数 + 1）
        let higherCount = userDistances.values.filter { $0 > totalDistance }.count
        let rank = higherCount + 1

        return rank
    }
}
