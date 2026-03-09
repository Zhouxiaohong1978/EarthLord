//
//  ExplorationManager.swift
//  EarthLord
//
//  探索功能核心管理器 - 管理GPS追踪、距离计算、速度检测和奖励生成
//

import Foundation
import CoreLocation
import Combine
import Supabase
import MapKit

// MARK: - ExplorationError

/// 探索功能错误类型
enum ExplorationError: LocalizedError {
    case notAuthenticated
    case locationNotAvailable
    case explorationAlreadyInProgress
    case noExplorationInProgress
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .locationNotAvailable:
            return "无法获取位置信息"
        case .explorationAlreadyInProgress:
            return "探索已在进行中"
        case .noExplorationInProgress:
            return "没有正在进行的探索"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        }
    }
}

// MARK: - ExplorationManager

/// 探索功能核心管理器
@MainActor
final class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = ExplorationManager()

    // MARK: - Constants

    /// 速度限制 (km/h)
    private let speedLimit: Double = 30.0

    /// 超速警告倒计时 (秒)
    private let warningDuration: Int = 15

    /// 最小记录距离 (米) - GPS 点之间的最小距离
    private let minimumRecordDistance: CLLocationDistance = 5.0

    /// 最大单次跳跃距离 (米) - 超过此距离认为是 GPS 跳点
    private let maxJumpDistance: CLLocationDistance = 100.0

    /// GPS 精度阈值 (米) - 精度差于此值的点将被忽略
    private let accuracyThreshold: CLLocationAccuracy = 50.0

    /// 最小时间间隔 (秒) - 两次记录之间的最小间隔
    private let minimumTimeInterval: TimeInterval = 1.0

    // MARK: - Published Properties

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 探索状态
    @Published var explorationState: ExplorationState = .idle

    /// 累计行走距离 (米)
    @Published var totalDistance: Double = 0

    /// 当前速度 (km/h)
    @Published var currentSpeed: Double = 0

    /// 超速倒计时 (秒)
    @Published var overSpeedCountdown: Int?

    /// 探索时长 (秒)
    @Published var explorationDuration: TimeInterval = 0

    /// 记录的最高速度 (km/h)
    @Published var maxRecordedSpeed: Double = 0

    /// 探索结果 (探索结束后设置)
    @Published var explorationResult: ExplorationSessionResult?

    /// 探索路径坐标（用于地图显示）
    @Published var explorationPathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发地图刷新）
    @Published var explorationPathVersion: Int = 0

    // MARK: - POI相关属性

    /// 当前探索会话的POI列表
    @Published var nearbyPOIs: [POI] = []

    /// 当前接近的POI（触发弹窗）
    @Published var currentProximityPOI: POI?

    /// 是否显示接近弹窗
    @Published var showProximityPopup: Bool = false

    /// 已搜刮的POI ID集合（本次探索会话）
    @Published var scavengedPOIIds: Set<UUID> = []

    /// 搜刮结果（用于展示给用户确认）
    @Published var scavengeResult: ScavengeResult?

    /// 是否显示搜刮结果弹窗
    @Published var showScavengeResult: Bool = false

    // MARK: - Private Properties

    /// 位置管理器
    private var locationManager: CLLocationManager?

    /// 探索开始时间
    private var startTime: Date?

    /// 上一个有效位置
    private var lastValidLocation: CLLocation?

    /// 上一次记录的时间
    private var lastRecordTime: Date?

    /// 探索路径点
    private var pathPoints: [(coordinate: CLLocationCoordinate2D, timestamp: Date)] = []

    /// 超速计时器
    private var overSpeedTimer: Timer?

    /// 当前倒计时值
    private var countdownValue: Int = 10

    /// 探索时长计时器
    private var durationTimer: Timer?

    /// 日志器
    private let logger = ExplorationLogger.shared

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    /// 设置位置管理器
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = minimumRecordDistance
        // 启用后台定位（核心玩法，免费用户可用，需 Info.plist 配置 UIBackgroundModes: location）
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false

        logger.log("位置管理器初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() {
        logger.log("========== 开始探索请求 ==========", type: .info)

        guard !isExploring else {
            logger.logError("探索已在进行中，无法重复开始")
            return
        }

        // 检查定位权限
        guard let locationManager = locationManager else {
            logger.logError("位置管理器未初始化")
            return
        }

        let authStatus = locationManager.authorizationStatus
        logger.log("定位权限状态: \(authStatus.rawValue)", type: .info)

        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            logger.logError("定位权限未授权，当前状态: \(authStatus.rawValue)")
            return
        }

        // 重置状态
        resetExplorationState()

        // 开始探索
        isExploring = true
        explorationState = .exploring
        startTime = Date()

        // 开始位置更新
        locationManager.startUpdatingLocation()
        logger.log("已启动位置更新服务", type: .info)

        // 开始时长计时
        startDurationTimer()
        logger.log("已启动探索计时器", type: .info)

        logger.logExplorationStart()
        logger.logStateChange(from: "idle", to: "exploring")
        logger.log("速度限制: \(speedLimit) km/h, 超速警告时间: \(warningDuration) 秒", type: .info)

        // 搜索附近POI
        Task {
            guard let location = locationManager.location else { return }
            await searchNearbyPOIs(center: location.coordinate)
            setupGeofences()
        }
    }

    /// 停止探索并返回结果
    /// - Parameter cancelled: 是否为用户主动取消
    /// - Returns: 探索会话结果
    @discardableResult
    func stopExploration(cancelled: Bool = false) -> ExplorationSessionResult? {
        logger.log("========== 停止探索请求 ==========", type: .info)
        logger.log("是否取消: \(cancelled)", type: .info)

        guard isExploring else {
            logger.logError("没有正在进行的探索")
            return nil
        }

        // 停止位置更新
        locationManager?.stopUpdatingLocation()
        logger.log("已停止位置更新服务", type: .info)

        // 停止计时器
        stopDurationTimer()
        cancelOverSpeedCountdown()

        // 清理POI和地理围栏
        cleanupGeofences()
        scavengedPOIIds.removeAll()
        currentProximityPOI = nil
        showProximityPopup = false

        // 计算结果
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(startTime ?? endTime))
        let status = cancelled ? "cancelled" : "completed"

        // 计算奖励
        let rewardTier = RewardTier.from(distance: totalDistance)
        let rewards = cancelled ? [] : generateRewards(tier: rewardTier)

        // 创建结果
        let result = ExplorationSessionResult(
            id: UUID(),
            startTime: startTime ?? endTime,
            endTime: endTime,
            distanceWalked: totalDistance,
            durationSeconds: duration,
            status: status,
            rewardTier: rewardTier,
            obtainedItems: rewards,
            path: pathPoints,
            maxSpeed: maxRecordedSpeed
        )

        // 更新状态
        isExploring = false
        explorationState = .completed(result: result)
        explorationResult = result

        logger.logExplorationEnd(distance: totalDistance, duration: duration, status: status)
        logger.logStateChange(from: "exploring", to: "completed")

        // 异步保存到数据库
        Task {
            await saveExplorationToDatabase(result: result, rewards: rewards)
        }

        return result
    }

    /// 取消探索
    func cancelExploration() {
        stopExploration(cancelled: true)
    }

    /// 重置探索状态（用于开始新的探索）
    func resetExplorationState() {
        isExploring = false
        explorationState = .idle
        totalDistance = 0
        currentSpeed = 0
        overSpeedCountdown = nil
        explorationDuration = 0
        maxRecordedSpeed = 0
        explorationResult = nil
        startTime = nil
        lastValidLocation = nil
        lastRecordTime = nil
        pathPoints.removeAll()
        explorationPathCoordinates.removeAll()
        explorationPathVersion += 1

        cancelOverSpeedCountdown()
        stopDurationTimer()

        logger.log("探索状态已重置", type: .info)
    }

    // MARK: - Location Handling

    /// 处理位置更新
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else {
            logger.log("收到位置更新但探索未进行，忽略", type: .warning)
            return
        }

        // 检查精度
        if location.horizontalAccuracy > accuracyThreshold || location.horizontalAccuracy < 0 {
            logger.log(
                String(format: "忽略低精度位置: 精度 %.1fm > 阈值 %.1fm", location.horizontalAccuracy, accuracyThreshold),
                type: .warning
            )
            return
        }

        // 记录 GPS 日志
        logger.logGPS(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            speed: location.speed >= 0 ? location.speed * 3.6 : nil
        )

        // 计算速度
        let speedKmh = calculateSpeed(from: location)
        currentSpeed = speedKmh

        // 记录最高速度
        if speedKmh > maxRecordedSpeed {
            maxRecordedSpeed = speedKmh
            logger.log(String(format: "新最高速度记录: %.1f km/h", speedKmh), type: .info)
        }

        // 速度检测
        let isOverSpeed = speedKmh > speedLimit
        logger.logSpeed(speedKmh, isOverSpeed: isOverSpeed, countdown: overSpeedCountdown)

        if isOverSpeed {
            logger.log(String(format: "⚠️ 检测到超速: %.1f km/h > %.1f km/h", speedKmh, speedLimit), type: .warning)
            handleOverSpeed()
        } else {
            handleNormalSpeed(location: location)
        }

        // 主动检测接近的POI（解决已在范围内不触发的问题）
        checkPOIProximity(location: location)
    }

    /// 计算速度 (km/h)
    private func calculateSpeed(from location: CLLocation) -> Double {
        // 优先使用系统提供的速度
        if location.speed >= 0 {
            return location.speed * 3.6  // m/s 转 km/h
        }

        // 手动计算速度
        guard let lastLocation = lastValidLocation,
              let lastTime = lastRecordTime else {
            return 0
        }

        let distance = location.distance(from: lastLocation)
        let timeDelta = location.timestamp.timeIntervalSince(lastTime)

        guard timeDelta > 0 else { return 0 }

        let speedMs = distance / timeDelta
        return speedMs * 3.6  // m/s 转 km/h
    }

    /// 处理超速情况
    private func handleOverSpeed() {
        if overSpeedTimer == nil {
            startOverSpeedCountdown()
        }
    }

    /// 处理正常速度
    private func handleNormalSpeed(location: CLLocation) {
        // 如果之前在超速状态，取消倒计时
        if overSpeedTimer != nil {
            cancelOverSpeedCountdown()
        }

        // 检查是否需要记录这个点
        if shouldRecordPoint(location: location) {
            recordPathPoint(location: location)
        }
    }

    /// 判断是否应该记录这个点
    private func shouldRecordPoint(location: CLLocation) -> Bool {
        // 第一个点
        guard let lastLocation = lastValidLocation,
              let lastTime = lastRecordTime else {
            return true
        }

        // 检查时间间隔
        let timeDelta = location.timestamp.timeIntervalSince(lastTime)
        if timeDelta < minimumTimeInterval {
            return false
        }

        // 检查距离
        let distance = location.distance(from: lastLocation)

        // 检查是否为 GPS 跳点
        if distance > maxJumpDistance {
            logger.log(
                String(format: "忽略 GPS 跳点: 距离 %.1fm > %.1fm", distance, maxJumpDistance),
                type: .warning
            )
            return false
        }

        return distance >= minimumRecordDistance
    }

    /// 记录路径点
    private func recordPathPoint(location: CLLocation) {
        // 计算与上一点的距离
        var segmentDistance: Double = 0
        if let lastLocation = lastValidLocation {
            segmentDistance = location.distance(from: lastLocation)
            totalDistance += segmentDistance
            logger.log(
                String(format: "📍 记录新位置点: 本段 +%.1fm, 累计 %.1fm, 路径点数: %d",
                       segmentDistance, totalDistance, pathPoints.count + 1),
                type: .distance
            )
        } else {
            logger.log("📍 记录首个位置点", type: .distance)
        }

        // 记录点
        pathPoints.append((location.coordinate, location.timestamp))
        lastValidLocation = location
        lastRecordTime = location.timestamp

        // 同步更新用于地图显示的路径坐标
        explorationPathCoordinates.append(location.coordinate)
        explorationPathVersion += 1

        logger.logDistance(segmentDistance: segmentDistance, totalDistance: totalDistance)
    }

    // MARK: - Over Speed Handling

    /// 开始超速倒计时
    private func startOverSpeedCountdown() {
        countdownValue = warningDuration
        overSpeedCountdown = countdownValue
        explorationState = .overSpeedWarning(secondsRemaining: countdownValue)

        logger.log("🚨 ========== 超速警告开始 ==========", type: .warning)
        logger.log(
            String(format: "当前速度: %.1f km/h, 限制: %.1f km/h", currentSpeed, speedLimit),
            type: .warning
        )
        logger.log("倒计时: \(warningDuration) 秒内需降低速度，否则探索将失败", type: .warning)
        logger.logStateChange(from: "exploring", to: "overSpeedWarning(\(countdownValue))")

        overSpeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    /// 倒计时滴答
    private func tickCountdown() {
        countdownValue -= 1
        overSpeedCountdown = countdownValue
        explorationState = .overSpeedWarning(secondsRemaining: countdownValue)

        logger.log(
            String(format: "⏱️ 超速倒计时: %d 秒, 当前速度: %.1f km/h", countdownValue, currentSpeed),
            type: .warning
        )

        if countdownValue <= 0 {
            logger.log("⏱️ 倒计时结束，检查当前速度...", type: .warning)
            // 倒计时结束，检查当前速度
            if currentSpeed > speedLimit {
                // 仍然超速，探索失败
                logger.log(
                    String(format: "❌ 速度仍超限 (%.1f > %.1f)，探索失败！", currentSpeed, speedLimit),
                    type: .error
                )
                failExploration()
            } else {
                // 速度已恢复，取消倒计时
                logger.log(
                    String(format: "✅ 速度已恢复正常 (%.1f km/h)，继续探索", currentSpeed),
                    type: .success
                )
                cancelOverSpeedCountdown()
            }
        }
    }

    /// 取消超速倒计时
    private func cancelOverSpeedCountdown() {
        overSpeedTimer?.invalidate()
        overSpeedTimer = nil
        overSpeedCountdown = nil

        if isExploring, case .overSpeedWarning = explorationState {
            explorationState = .exploring
            logger.log("✓ 速度恢复正常，取消超速倒计时", type: .success)
            logger.logStateChange(from: "overSpeedWarning", to: "exploring")
        }
    }

    /// 探索失败（超速）
    private func failExploration() {
        logger.log("🛑 ========== 探索失败处理 ==========", type: .error)
        logger.log(
            String(format: "失败原因: 超速时间过长 (持续超过 %d 秒)", warningDuration),
            type: .error
        )
        logger.log(
            String(format: "最终速度: %.1f km/h, 行走距离: %.1fm, 路径点: %d",
                   currentSpeed, totalDistance, pathPoints.count),
            type: .error
        )

        overSpeedTimer?.invalidate()
        overSpeedTimer = nil

        // 停止位置更新
        locationManager?.stopUpdatingLocation()
        logger.log("已停止位置更新服务", type: .info)

        // 停止计时器
        stopDurationTimer()

        // 更新状态
        isExploring = false
        explorationState = .failed(reason: .overSpeed)

        logger.logError("探索失败！超速时间过长")
        logger.logStateChange(from: "overSpeedWarning", to: "failed(overSpeed)")

        // 保存失败记录
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(startTime ?? endTime))

        let result = ExplorationSessionResult(
            id: UUID(),
            startTime: startTime ?? endTime,
            endTime: endTime,
            distanceWalked: totalDistance,
            durationSeconds: duration,
            status: "failed_overspeed",
            rewardTier: .none,
            obtainedItems: [],
            path: pathPoints,
            maxSpeed: maxRecordedSpeed
        )

        explorationResult = result

        Task {
            await saveExplorationToDatabase(result: result, rewards: [])
        }
    }

    // MARK: - Duration Timer

    /// 开始探索时长计时
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.startTime else { return }
                self.explorationDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// 停止探索时长计时
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Reward Generation

    /// 生成奖励物品
    private func generateRewards(tier: RewardTier) -> [ObtainedItem] {
        guard tier != .none else {
            logger.log("距离不足，无奖励", type: .info)
            return []
        }

        let subscriptionTier = SubscriptionManager.shared.currentTier
        let itemCount = tier.adjustedItemCount(for: subscriptionTier)
        if subscriptionTier != .free {
            logger.log("订阅加成: \(subscriptionTier.rawValue) × \(subscriptionTier.walkRewardMultiplier) → \(itemCount) 件物品", type: .info)
        }
        var tempRewards: [ObtainedItem] = []

        // 先生成所有物品
        for _ in 0..<itemCount {
            let item = generateRandomItem(tier: tier)
            tempRewards.append(item)
        }

        // 合并相同物品（相同 itemId 和 quality 的物品堆叠）
        var mergedRewards: [String: ObtainedItem] = [:]
        for item in tempRewards {
            let key = "\(item.itemId)_\(item.quality?.rawValue ?? "none")"
            if let existing = mergedRewards[key] {
                // 已存在相同物品，增加数量
                mergedRewards[key] = ObtainedItem(
                    itemId: existing.itemId,
                    quantity: existing.quantity + item.quantity,
                    quality: existing.quality
                )
            } else {
                mergedRewards[key] = item
            }
        }

        let rewards = Array(mergedRewards.values)

        logger.logReward(tier: tier, itemCount: itemCount, items: rewards)
        return rewards
    }

    /// 生成随机物品
    private func generateRandomItem(tier: RewardTier) -> ObtainedItem {
        let randomValue = Double.random(in: 0...1)

        // 根据5级概率确定稀有度
        let rarity: ItemRarity
        let p0 = tier.commonProbability
        let p1 = p0 + tier.uncommonProbability
        let p2 = p1 + tier.rareProbability
        let p3 = p2 + tier.epicProbability

        if randomValue < p0 {
            rarity = .common
        } else if randomValue < p1 {
            rarity = .uncommon
        } else if randomValue < p2 {
            rarity = .rare
        } else if randomValue < p3 {
            rarity = .epic
        } else {
            rarity = .legendary
        }

        // 从对应稀有度的物品池中随机选择
        let itemPool = getItemPool(for: rarity)
        let selectedItem = itemPool.randomElement() ?? "water_bottle"

        // 随机品质
        let quality = generateRandomQuality()

        return ObtainedItem(
            itemId: selectedItem,
            quantity: 1,
            quality: quality
        )
    }

    /// 获取指定稀有度的物品池（GDD对齐，所有等级包含建造材料）
    private func getItemPool(for rarity: ItemRarity) -> [String] {
        switch rarity {
        case .common:
            // 生存基础 + 核心建造材料（木头/石头）
            return ["water_bottle", "canned_food", "bread", "bandage", "wood", "stone", "cloth"]
        case .uncommon:
            // 进阶建造材料 + 基础工具
            return ["scrap_metal", "nails", "rope", "seeds", "medicine", "tool"]
        case .rare:
            // Tier2 建造材料 + 工具箱
            return ["first_aid_kit", "toolbox", "fuel", "blueprint_basic", "build_speedup"]
        case .epic:
            // Tier3 稀有材料 + 医疗品
            return ["electronic_component", "antibiotics", "scavenge_pass", "equipment_rare"]
        case .legendary:
            // 顶级材料 + 蓝图
            return ["satellite_module", "blueprint_epic", "equipment_epic"]
        }
    }

    /// 生成随机品质
    private func generateRandomQuality() -> ItemQuality {
        let randomValue = Double.random(in: 0...1)
        if randomValue < 0.1 {
            return .broken
        } else if randomValue < 0.25 {
            return .worn
        } else if randomValue < 0.60 {
            return .normal
        } else if randomValue < 0.85 {
            return .good
        } else {
            return .excellent
        }
    }

    // MARK: - Database Operations

    /// 保存探索记录到数据库
    private func saveExplorationToDatabase(result: ExplorationSessionResult, rewards: [ObtainedItem]) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            logger.logError("无法保存：用户未登录")
            return
        }

        // 尝试直接保存到服务器（不预先检查网络状态，让实际网络请求来判断）
        do {
            // 保存探索会话
            let sessionId = try await saveExplorationSession(result: result, userId: userId)
            logger.log("✅ 探索会话已保存: \(sessionId)", type: .success)

            // 保存奖励物品到背包（使用 InventoryManager 以支持堆叠）
            if !rewards.isEmpty {
                await saveRewardsToInventory(items: rewards, sessionId: sessionId)
                logger.log("✅ 已保存 \(rewards.count) 件物品到背包", type: .success)
            }
        } catch {
            logger.logError("⚠️ 离线同步检测失败，保存到待同步包", error: error)
            // 保存失败（可能是网络问题），加入离线队列
            saveToOfflineQueue(result: result, rewards: rewards)
        }
    }

    /// 保存到离线队列
    private func saveToOfflineQueue(result: ExplorationSessionResult, rewards: [ObtainedItem]) {
        // 保存探索会话到离线队列
        OfflineSyncManager.shared.addPendingSession(
            startTime: result.startTime,
            endTime: result.endTime,
            distanceWalked: result.distanceWalked,
            durationSeconds: result.durationSeconds,
            status: result.status,
            rewardTier: result.rewardTier.rawValue,
            maxSpeed: result.maxSpeed
        )

        // 保存物品到离线队列
        for item in rewards {
            OfflineSyncManager.shared.addPendingItem(
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality,
                obtainedFrom: "探索",
                sessionId: nil
            )
        }

        logger.log("✅ 已保存 \(rewards.count) 件物品到离线队列，网络恢复后自动同步", type: .success)
    }

    /// 保存奖励物品到背包（使用 InventoryManager 支持堆叠）
    private func saveRewardsToInventory(items: [ObtainedItem], sessionId: String) async {
        var failedItems: [ObtainedItem] = []

        for item in items {
            do {
                try await InventoryManager.shared.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "探索",
                    sessionId: sessionId
                )
                logger.log("✅ 物品已添加到背包: \(item.itemId) x\(item.quantity)", type: .success)
            } catch {
                logger.logError("❌ 添加物品到背包失败: \(item.itemId)", error: error)
                failedItems.append(item)
            }
        }

        // 统一处理失败的物品
        if !failedItems.isEmpty {
            logger.log("⚠️ 有 \(failedItems.count) 件物品保存失败，加入离线队列", type: .warning)
            for item in failedItems {
                OfflineSyncManager.shared.addPendingItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "探索",
                    sessionId: sessionId
                )
            }
        }
    }

    /// 保存探索会话
    private func saveExplorationSession(result: ExplorationSessionResult, userId: UUID) async throws -> String {
        let dateFormatter = ISO8601DateFormatter()

        // 注：路径数据暂不保存，后续可按需添加
        let sessionData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "started_at": .string(dateFormatter.string(from: result.startTime)),
            "ended_at": .string(dateFormatter.string(from: result.endTime)),
            "distance_walked": .double(result.distanceWalked),
            "duration_seconds": .integer(result.durationSeconds),
            "status": .string(result.status),
            "reward_tier": .string(result.rewardTier.rawValue),
            "max_speed": .double(result.maxSpeed)
        ]

        let response = try await supabase
            .from("exploration_sessions")
            .insert(sessionData)
            .select("id")
            .single()
            .execute()

        // 解析返回的 ID
        struct InsertResponse: Codable {
            let id: String
        }

        let insertResponse = try JSONDecoder().decode(InsertResponse.self, from: response.data)
        return insertResponse.id
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            handleLocationUpdate(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.logError("位置更新失败", error: error)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            logger.log("定位授权状态变化: \(status.rawValue)", type: .info)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        Task { @MainActor in
            handlePOIProximity(regionId: circularRegion.identifier)
        }
    }
}

// MARK: - POI 搜索和围栏管理

extension ExplorationManager {

    /// 搜索附近真实POI（使用MapKit）- 根据玩家密度动态调整数量
    private func searchNearbyPOIs(center: CLLocationCoordinate2D) async {
        logger.log("🔍 开始搜索POI - 中心坐标: \(center.latitude), \(center.longitude)", type: .info)

        // ====== 查询玩家密度并确定POI数量 ======
        var targetPOICount: Int = 12  // 默认12个POI（中等密度）

        do {
            let densityResult = try await PlayerDensityService.shared.queryNearbyPlayers(
                latitude: center.latitude,
                longitude: center.longitude
            )

            let level = densityResult.densityLevel
            let recommendedCount = level.recommendedPOICount

            // 根据推荐数量决定实际显示的POI数量
            if recommendedCount == -1 {
                // 不限制：低密度区域，显示所有找到的POI（最多20个）
                targetPOICount = 20
                logger.log("👥 附近玩家: \(densityResult.nearbyCount) 人, 密度: \(level.rawValue) - 不限制POI数量（最多20个）", type: .info)
            } else {
                // 限制数量：按玩家密度动态调整
                targetPOICount = recommendedCount
                logger.log("👥 附近玩家: \(densityResult.nearbyCount) 人, 密度: \(level.rawValue) - 限制 \(targetPOICount) 个POI", type: .info)
            }

        } catch {
            logger.logError("玩家密度查询失败，使用默认策略(12个POI)", error: error)
            targetPOICount = 12  // 查询失败时默认中等密度
        }
        // ====== 密度查询结束 ======

        // 根据App当前语言设置动态选择搜索关键词
        let languageManager = LanguageManager.shared
        let isEnglish = languageManager.currentLocale == "en"

        let searchQueries: [(query: String, type: POIType)] = isEnglish ? [
            ("supermarket", .supermarket),
            ("convenience store", .supermarket),
            ("hospital", .hospital),
            ("clinic", .hospital),
            ("pharmacy", .pharmacy),
            ("drug store", .pharmacy),
            ("gas station", .gasStation),
            ("restaurant", .restaurant),
            ("cafe", .restaurant),
            ("coffee", .restaurant)
        ] : [
            ("超市", .supermarket),
            ("便利店", .supermarket),
            ("医院", .hospital),
            ("诊所", .hospital),
            ("药店", .pharmacy),
            ("药房", .pharmacy),
            ("加油站", .gasStation),
            ("餐厅", .restaurant),
            ("饭店", .restaurant),
            ("咖啡厅", .restaurant)
        ]

        var allResults: [POI] = []
        let maxPerQuery = 3  // 每个关键词最多取3个，确保多样性
        var seenCoordinates: Set<String> = []  // 用于去重

        for (query, poiType) in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()
                logger.log("📍 搜索「\(query)」找到 \(response.mapItems.count) 个结果", type: .info)

                // 每个关键词只取前几个，确保类型多样性
                var addedCount = 0
                for mapItem in response.mapItems {
                    guard addedCount < maxPerQuery else { break }

                    // 按坐标去重（精确到小数点后4位，约11米精度）
                    let coordKey = String(format: "%.4f,%.4f",
                                         mapItem.placemark.coordinate.latitude,
                                         mapItem.placemark.coordinate.longitude)
                    guard !seenCoordinates.contains(coordKey) else { continue }
                    seenCoordinates.insert(coordKey)

                    let poi = convertMapItemToPOI(mapItem, overrideType: poiType)
                    logger.log("  - \(poi.name) (\(poi.type.displayName))", type: .info)
                    allResults.append(poi)
                    addedCount += 1
                }
            } catch {
                logger.logError("搜索POI失败: \(query)", error: error)
            }
        }

        // ====== 方位均衡分布算法 ======
        let userLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        // 按方位角度分组（东南西北四个象限）
        var quadrants: [String: [POI]] = [
            "东北": [], // 0°-90°
            "东南": [], // 90°-180°
            "西南": [], // 180°-270°
            "西北": []  // 270°-360°
        ]

        // 获取探索范围（基于订阅档位：1.0/2.0/3.0 km）
        let explorationRadius = SubscriptionManager.shared.explorationRadius * 1000 // 转换为米

        for poi in allResults {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userLocation.distance(from: poiLocation)

            // 只保留探索范围内的POI
            guard distance <= explorationRadius else { continue }

            // 计算方位角（0°=正北，顺时针）
            let dx = poi.coordinate.longitude - center.longitude
            let dy = poi.coordinate.latitude - center.latitude
            var bearing = atan2(dx, dy) * 180 / .pi
            if bearing < 0 { bearing += 360 }

            // 分配到象限
            if bearing >= 0 && bearing < 90 {
                quadrants["东北"]?.append(poi)
            } else if bearing >= 90 && bearing < 180 {
                quadrants["东南"]?.append(poi)
            } else if bearing >= 180 && bearing < 270 {
                quadrants["西南"]?.append(poi)
            } else {
                quadrants["西北"]?.append(poi)
            }
        }

        // 每个象限按距离排序
        for key in quadrants.keys {
            quadrants[key]?.sort { poi1, poi2 in
                let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
                let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
                return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
            }
        }

        // 根据玩家密度动态分配：从每个象限均衡选取POI
        var balancedResults: [POI] = []
        let perQuadrant = targetPOICount / 4  // 每个象限的基础配额

        logger.log("🧭 \(String(format: "%.0f", explorationRadius))米范围内POI方位分布:", type: .info)
        for (direction, pois) in quadrants.sorted(by: { $0.key < $1.key }) {
            logger.log("  \(direction)象限: 找到 \(pois.count) 个POI", type: .info)
        }

        // 第一轮：从每个象限均衡选取基础配额
        for (_, pois) in quadrants {
            balancedResults.append(contentsOf: pois.prefix(perQuadrant))
        }

        // 第二轮：如果还有配额，从有POI的象限补充（优先补充POI多的象限）
        if balancedResults.count < targetPOICount {
            let remaining = targetPOICount - balancedResults.count
            let allRemaining = quadrants.values.flatMap { $0 }.filter { poi in
                !balancedResults.contains(where: { $0.id == poi.id })
            }
            // 按距离排序，优先选择最近的
            let sortedRemaining = allRemaining.sorted { poi1, poi2 in
                let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
                let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
                return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
            }
            balancedResults.append(contentsOf: sortedRemaining.prefix(remaining))
            logger.log("📊 基础配额不足，从剩余POI中补充 \(min(remaining, sortedRemaining.count)) 个", type: .info)
        }

        allResults = balancedResults
        logger.log("✅ 全方位均衡分配完成：显示 \(allResults.count) 个POI（玩家密度推荐:\(targetPOICount)个）", type: .success)
        // ====== 方位均衡结束 ======

        nearbyPOIs = allResults
        logger.log("✅ 总共显示 \(nearbyPOIs.count) 个附近POI", type: .success)

        if nearbyPOIs.isEmpty {
            logger.log("⚠️ 未找到任何POI，可能原因：", type: .warning)
            logger.log("  1. 当前位置附近5公里内没有MapKit POI数据", type: .warning)
            logger.log("  2. MapKit在中国大陆的POI数据可能不完整", type: .warning)
            logger.log("  3. 建议切换到高德地图或百度地图API获取更准确的POI数据", type: .warning)
        }
    }

    /// 将MapKit结果转换为POI模型
    /// - Parameters:
    ///   - mapItem: MapKit搜索结果
    ///   - overrideType: 指定POI类型（用于中文关键词搜索时）
    private func convertMapItemToPOI(_ mapItem: MKMapItem, overrideType: POIType? = nil) -> POI {
        let poiType = overrideType ?? mapPOICategoryToPOIType(mapItem.pointOfInterestCategory)

        return POI(
            name: mapItem.name ?? "未知地点",
            type: poiType,
            coordinate: mapItem.placemark.coordinate,
            status: .undiscovered,
            description: mapItem.placemark.title ?? "",
            estimatedResources: [],
            dangerLevel: 1
        )
    }

    /// MapKit类型映射到游戏POI类型
    private func mapPOICategoryToPOIType(_ category: MKPointOfInterestCategory?) -> POIType {
        guard let category = category else { return .residential }

        switch category {
        case .store, .foodMarket: return .supermarket
        case .restaurant, .cafe, .bakery: return .restaurant
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .police: return .police
        case .bank, .atm: return .warehouse
        default: return .residential
        }
    }

    /// 为所有POI创建地理围栏
    private func setupGeofences() {
        guard let locationManager = locationManager else { return }

        // 清除旧围栏
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        // 为每个POI创建50米围栏
        for poi in nearbyPOIs {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: 50.0,
                identifier: poi.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoring(for: region)
        }

        logger.log("已创建 \(nearbyPOIs.count) 个地理围栏", type: .info)
    }

    /// 清理所有地理围栏
    private func cleanupGeofences() {
        guard let locationManager = locationManager else { return }

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        nearbyPOIs.removeAll()
        logger.log("已清理地理围栏", type: .info)
    }

    /// 处理进入POI范围
    @MainActor
    private func handlePOIProximity(regionId: String) {
        guard let poiId = UUID(uuidString: regionId),
              let poi = nearbyPOIs.first(where: { $0.id == poiId }),
              !scavengedPOIIds.contains(poiId) else {
            return
        }

        logger.log("进入POI范围: \(poi.name)", type: .info)

        currentProximityPOI = poi
        showProximityPopup = true
    }

    /// 主动检测是否接近POI（解决地理围栏"已在范围内"不触发的问题）
    private func checkPOIProximity(location: CLLocation) {
        // 已有弹窗显示时不检测
        guard currentProximityPOI == nil, !showProximityPopup else { return }

        // 将GPS坐标（WGS-84）转换为GCJ-02，与MapKit返回的POI坐标对比
        let gcj02Coord = CoordinateConverter.wgs84ToGcj02(location.coordinate)
        let userLocationGCJ02 = CLLocation(latitude: gcj02Coord.latitude, longitude: gcj02Coord.longitude)

        for poi in nearbyPOIs {
            // 跳过已搜刮的POI
            guard !scavengedPOIIds.contains(poi.id) else { continue }

            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userLocationGCJ02.distance(from: poiLocation)

            if distance <= 50.0 {
                logger.log("📍 主动检测到接近POI: \(poi.name)，距离: \(String(format: "%.1f", distance))m", type: .info)
                handlePOIProximity(regionId: poi.id.uuidString)
                break
            }
        }
    }

    /// 搜刮POI获得物品（AI生成，等待用户确认）
    func scavengePOI(_ poi: POI) async {
        logger.log("开始搜刮: \(poi.name), 危险等级: \(poi.dangerLevel)", type: .info)

        scavengedPOIIds.insert(poi.id)

        let itemCount = Int.random(in: 1...3)
        var aiItems: [AIGeneratedItem] = []
        var generatedByAI = true

        do {
            // 尝试使用AI生成物品
            aiItems = try await AIItemGenerator.shared.generateItems(for: poi, itemCount: itemCount)
        } catch {
            // AI生成失败，使用本地预设物品作为降级方案
            logger.log("⚠️ AI生成失败，使用本地预设物品: \(error.localizedDescription)", type: .warning)
            aiItems = generateFallbackItems(for: poi, count: itemCount)
            generatedByAI = false
        }

        let sessionId = "scavenge_\(poi.id.uuidString)"

        // 创建搜刮结果，等待用户确认
        scavengeResult = ScavengeResult(
            poi: poi,
            items: aiItems,
            sessionId: sessionId,
            generatedByAI: generatedByAI
        )
        showScavengeResult = true

        logger.log("搜刮完成，生成 \(aiItems.count) 件物品（AI:\(generatedByAI)），等待用户确认", type: .info)
    }

    /// 降级方案：生成本地预设物品
    private func generateFallbackItems(for poi: POI, count: Int) -> [AIGeneratedItem] {
        var items: [AIGeneratedItem] = []

        for _ in 0..<count {
            let rarity = determineRarityByDangerLevel(poi.dangerLevel)
            let fallbackItem = getFallbackItem(for: poi.type, rarity: rarity)
            items.append(fallbackItem)
        }

        return items
    }

    /// 根据危险等级确定稀有度
    private func determineRarityByDangerLevel(_ dangerLevel: Int) -> String {
        let randomValue = Double.random(in: 0...1)

        switch dangerLevel {
        case 1, 2:
            if randomValue < 0.70 { return "common" }
            else if randomValue < 0.95 { return "uncommon" }
            else { return "rare" }
        case 3:
            if randomValue < 0.50 { return "common" }
            else if randomValue < 0.80 { return "uncommon" }
            else if randomValue < 0.95 { return "rare" }
            else { return "epic" }
        case 4:
            if randomValue < 0.40 { return "uncommon" }
            else if randomValue < 0.75 { return "rare" }
            else if randomValue < 0.95 { return "epic" }
            else { return "legendary" }
        case 5:
            if randomValue < 0.30 { return "rare" }
            else if randomValue < 0.70 { return "epic" }
            else { return "legendary" }
        default:
            return "common"
        }
    }

    /// 获取预设降级物品
    private func getFallbackItem(for poiType: POIType, rarity: String) -> AIGeneratedItem {
        // 根据POI类型选择物品
        let fallbackData: [(name: String, story: String, category: String)] = {
            switch poiType {
            case .hospital, .pharmacy:
                return [
                    ("急救医疗包", "从储物柜中找到的完整急救包，上面还贴着护士的名字。", "medical"),
                    ("过期止痛药", "虽然已经过期，但在末日中仍是珍贵的资源。", "medical"),
                    ("消毒纱布", "密封完好的医用纱布，包装上写着\"请勿私自取用\"。", "medical")
                ]
            case .supermarket, .restaurant:
                return [
                    ("罐头午餐肉", "货架深处发现的未开封罐头，生产日期已模糊不清。", "food"),
                    ("瓶装矿泉水", "落满灰尘的矿泉水，瓶身上印着\"清凉一夏\"的广告语。", "water"),
                    ("压缩饼干", "军用压缩饼干，保质期长达十年。", "food")
                ]
            case .factory, .warehouse:
                return [
                    ("生锈扳手", "一把沾满油污的扳手，手柄处刻着工人的名字缩写。", "tool"),
                    ("废旧电线", "从墙壁里扯出的电线，还能派上用场。", "material"),
                    ("破旧安全帽", "裂了一道缝的安全帽，但总比没有强。", "clothing")
                ]
            case .gasStation:
                return [
                    ("汽油桶残液", "油桶底部还剩一点汽油，珍贵的燃料。", "material"),
                    ("便利店零食", "收银台后面藏着的零食，店员的私藏。", "food"),
                    ("打火机", "加油站纪念品打火机，居然还能用。", "tool")
                ]
            case .police, .military:
                return [
                    ("警用手电", "警察标配的强光手电，电池还有电。", "tool"),
                    ("防刺手套", "出警时用的防护手套，磨损严重但仍可使用。", "clothing"),
                    ("对讲机", "已经没有信号的对讲机，也许能拆出有用的零件。", "tool")
                ]
            case .residential:
                return [
                    ("家庭相册", "封面已经泛黄的相册，记录着某个家庭曾经的幸福时光。", "misc"),
                    ("厨房刀具", "一把锋利的菜刀，刀柄上刻着\"妈妈的厨房\"。", "weapon"),
                    ("毛毯", "柔软的毛毯，带着淡淡的洗衣液香味。", "clothing")
                ]
            }
        }()

        let selected = fallbackData.randomElement() ?? ("废墟残骸", "从废墟中捡到的不明物品。", "misc")

        return AIGeneratedItem(
            name: selected.name,
            story: selected.story,
            category: selected.category,
            rarity: rarity,
            quantity: 1,
            quality: generateRandomQuality()
        )
    }

    /// 确认搜刮结果，将物品添加到背包
    func confirmScavengeResult() async {
        guard let result = scavengeResult else {
            logger.logError("没有待确认的搜刮结果")
            return
        }

        logger.log("用户确认搜刮结果，保存 \(result.items.count) 件物品到背包", type: .info)

        // 将 AIGeneratedItem 转换为 ObtainedItem
        let obtainedItems = result.items.map { $0.toObtainedItem() }
        await saveRewardsToInventory(items: obtainedItems, sessionId: result.sessionId)

        // 清除搜刮结果
        scavengeResult = nil
        showScavengeResult = false

        logger.log("物品已保存到背包", type: .success)
    }

    /// 放弃搜刮结果（用户不想要这些物品）
    func discardScavengeResult() {
        logger.log("用户放弃搜刮结果", type: .info)
        scavengeResult = nil
        showScavengeResult = false
    }
}
