//
//  OfflineSyncManager.swift
//  EarthLord
//
//  离线同步管理器 - 管理网络断开时的本地数据存储和恢复后的同步
//

import Foundation
import Network
import Combine
import Auth
import Supabase

// MARK: - 待同步物品模型

/// 待同步的物品数据
struct PendingInventoryItem: Codable, Identifiable {
    let id: UUID
    let itemId: String
    let quantity: Int
    let quality: String?
    let obtainedFrom: String?
    let sessionId: String?
    let createdAt: Date

    init(
        itemId: String,
        quantity: Int,
        quality: ItemQuality? = nil,
        obtainedFrom: String? = nil,
        sessionId: String? = nil
    ) {
        self.id = UUID()
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality?.rawValue
        self.obtainedFrom = obtainedFrom
        self.sessionId = sessionId
        self.createdAt = Date()
    }
}

/// 待同步的探索会话数据
struct PendingExplorationSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let distanceWalked: Double
    let durationSeconds: Int
    let status: String
    let rewardTier: String
    let maxSpeed: Double
    let createdAt: Date

    init(
        startTime: Date,
        endTime: Date,
        distanceWalked: Double,
        durationSeconds: Int,
        status: String,
        rewardTier: String,
        maxSpeed: Double
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.distanceWalked = distanceWalked
        self.durationSeconds = durationSeconds
        self.status = status
        self.rewardTier = rewardTier
        self.maxSpeed = maxSpeed
        self.createdAt = Date()
    }
}

// MARK: - OfflineSyncManager

/// 离线同步管理器（单例）
@MainActor
final class OfflineSyncManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = OfflineSyncManager()

    // MARK: - Published Properties

    /// 网络是否可用
    @Published var isNetworkAvailable: Bool = true

    /// 待同步物品数量
    @Published var pendingItemsCount: Int = 0

    /// 是否正在同步
    @Published var isSyncing: Bool = false

    // MARK: - Private Properties

    /// 网络监控器
    private let networkMonitor = NWPathMonitor()

    /// 监控队列
    private let monitorQueue = DispatchQueue(label: "com.earthlord.networkmonitor")

    /// 日志器
    private let logger = ExplorationLogger.shared

    /// UserDefaults 键
    private let pendingItemsKey = "pending_inventory_items"
    private let pendingSessionsKey = "pending_exploration_sessions"
    private let cachedInventoryKey = "cached_inventory_items"

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
        loadPendingCount()
        logger.log("OfflineSyncManager 初始化完成", type: .info)
    }

    // MARK: - Network Monitoring

    /// 设置网络监控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if !wasAvailable && self.isNetworkAvailable {
                    // 网络从断开变为连接，尝试同步
                    self.logger.log("🌐 网络已恢复，开始同步待处理数据...", type: .info)
                    await self.syncPendingData()
                } else if wasAvailable && !self.isNetworkAvailable {
                    self.logger.log("⚠️ 网络已断开，将启用离线模式", type: .warning)
                }
            }
        }

        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Pending Items Management

    /// 添加待同步物品
    func addPendingItem(
        itemId: String,
        quantity: Int,
        quality: ItemQuality? = nil,
        obtainedFrom: String? = nil,
        sessionId: String? = nil
    ) {
        var pendingItems = loadPendingItems()

        let newItem = PendingInventoryItem(
            itemId: itemId,
            quantity: quantity,
            quality: quality,
            obtainedFrom: obtainedFrom,
            sessionId: sessionId
        )

        pendingItems.append(newItem)
        savePendingItems(pendingItems)

        pendingItemsCount = pendingItems.count
        logger.log("📦 物品已添加到离线队列: \(itemId) x\(quantity)，当前队列: \(pendingItems.count) 件", type: .info)
    }

    /// 添加待同步探索会话
    func addPendingSession(
        startTime: Date,
        endTime: Date,
        distanceWalked: Double,
        durationSeconds: Int,
        status: String,
        rewardTier: String,
        maxSpeed: Double
    ) {
        var pendingSessions = loadPendingSessions()

        let newSession = PendingExplorationSession(
            startTime: startTime,
            endTime: endTime,
            distanceWalked: distanceWalked,
            durationSeconds: durationSeconds,
            status: status,
            rewardTier: rewardTier,
            maxSpeed: maxSpeed
        )

        pendingSessions.append(newSession)
        savePendingSessions(pendingSessions)

        logger.log("📍 探索会话已添加到离线队列，当前队列: \(pendingSessions.count) 条", type: .info)
    }

    /// 同步所有待处理数据
    func syncPendingData() async {
        guard isNetworkAvailable else {
            logger.log("网络不可用，跳过同步", type: .warning)
            return
        }

        guard !isSyncing else {
            logger.log("正在同步中，跳过", type: .info)
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        logger.log("========== 开始同步离线数据 ==========", type: .info)

        // 同步探索会话
        await syncPendingSessions()

        // 同步物品
        await syncPendingItems()

        // 刷新背包
        await InventoryManager.shared.refreshInventory()

        logger.log("========== 离线数据同步完成 ==========", type: .success)
    }

    /// 同步待处理的探索会话
    private func syncPendingSessions() async {
        let pendingSessions = loadPendingSessions()
        guard !pendingSessions.isEmpty else { return }

        logger.log("同步 \(pendingSessions.count) 条待处理探索会话...", type: .info)

        var successCount = 0
        var failedSessions: [PendingExplorationSession] = []

        for session in pendingSessions {
            do {
                try await syncSession(session)
                successCount += 1
            } catch {
                logger.logError("同步探索会话失败", error: error)
                failedSessions.append(session)
            }
        }

        // 保存失败的会话供下次重试
        savePendingSessions(failedSessions)

        logger.log("探索会话同步完成: 成功 \(successCount), 失败 \(failedSessions.count)", type: .info)
    }

    /// 同步单个探索会话
    private func syncSession(_ session: PendingExplorationSession) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        let dateFormatter = ISO8601DateFormatter()

        let sessionData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "started_at": .string(dateFormatter.string(from: session.startTime)),
            "ended_at": .string(dateFormatter.string(from: session.endTime)),
            "distance_walked": .double(session.distanceWalked),
            "duration_seconds": .integer(session.durationSeconds),
            "status": .string(session.status),
            "reward_tier": .string(session.rewardTier),
            "max_speed": .double(session.maxSpeed)
        ]

        try await SupabaseManager.shared.client
            .from("exploration_sessions")
            .insert(sessionData)
            .execute()

        logger.log("探索会话已同步到服务器", type: .success)
    }

    /// 同步待处理的物品
    private func syncPendingItems() async {
        let pendingItems = loadPendingItems()
        guard !pendingItems.isEmpty else { return }

        logger.log("同步 \(pendingItems.count) 件待处理物品...", type: .info)

        var successCount = 0
        var failedItems: [PendingInventoryItem] = []

        for item in pendingItems {
            do {
                let quality = item.quality.flatMap { ItemQuality(rawValue: $0) }
                try await InventoryManager.shared.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: quality,
                    obtainedFrom: item.obtainedFrom,
                    sessionId: item.sessionId
                )
                successCount += 1
            } catch {
                logger.logError("同步物品失败: \(item.itemId)", error: error)
                failedItems.append(item)
            }
        }

        // 保存失败的物品供下次重试
        savePendingItems(failedItems)
        pendingItemsCount = failedItems.count

        logger.log("物品同步完成: 成功 \(successCount), 失败 \(failedItems.count)", type: .info)
    }

    // MARK: - Local Inventory Cache

    /// 缓存背包数据到本地
    func cacheInventory(_ items: [BackpackItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: cachedInventoryKey)
            logger.log("已缓存 \(items.count) 件背包物品到本地", type: .info)
        }
    }

    /// 从本地加载缓存的背包数据
    func loadCachedInventory() -> [BackpackItem]? {
        guard let data = UserDefaults.standard.data(forKey: cachedInventoryKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        if let items = try? decoder.decode([BackpackItem].self, from: data) {
            logger.log("从本地缓存加载 \(items.count) 件背包物品", type: .info)
            return items
        }

        return nil
    }

    // MARK: - Private Storage Methods

    /// 加载待同步物品
    private func loadPendingItems() -> [PendingInventoryItem] {
        guard let data = UserDefaults.standard.data(forKey: pendingItemsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        return (try? decoder.decode([PendingInventoryItem].self, from: data)) ?? []
    }

    /// 保存待同步物品
    private func savePendingItems(_ items: [PendingInventoryItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: pendingItemsKey)
        }
    }

    /// 加载待同步探索会话
    private func loadPendingSessions() -> [PendingExplorationSession] {
        guard let data = UserDefaults.standard.data(forKey: pendingSessionsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        return (try? decoder.decode([PendingExplorationSession].self, from: data)) ?? []
    }

    /// 保存待同步探索会话
    private func savePendingSessions(_ sessions: [PendingExplorationSession]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(sessions) {
            UserDefaults.standard.set(data, forKey: pendingSessionsKey)
        }
    }

    /// 加载待同步数量
    private func loadPendingCount() {
        pendingItemsCount = loadPendingItems().count
    }

    /// 手动触发同步
    func manualSync() async {
        await syncPendingData()
    }

    /// 清空所有待同步数据（谨慎使用）
    func clearAllPendingData() {
        UserDefaults.standard.removeObject(forKey: pendingItemsKey)
        UserDefaults.standard.removeObject(forKey: pendingSessionsKey)
        pendingItemsCount = 0
        logger.log("已清空所有待同步数据", type: .warning)
    }
}
