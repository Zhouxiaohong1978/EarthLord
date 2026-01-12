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
    private let warningDuration: Int = 10

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
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false

        logger.log("位置管理器初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() {
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

        // 开始时长计时
        startDurationTimer()

        logger.logExplorationStart()
        logger.logStateChange(from: "idle", to: "exploring")
    }

    /// 停止探索并返回结果
    /// - Parameter cancelled: 是否为用户主动取消
    /// - Returns: 探索会话结果
    @discardableResult
    func stopExploration(cancelled: Bool = false) -> ExplorationSessionResult? {
        guard isExploring else {
            logger.logError("没有正在进行的探索")
            return nil
        }

        // 停止位置更新
        locationManager?.stopUpdatingLocation()

        // 停止计时器
        stopDurationTimer()
        cancelOverSpeedCountdown()

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

        cancelOverSpeedCountdown()
        stopDurationTimer()

        logger.log("探索状态已重置", type: .info)
    }

    // MARK: - Location Handling

    /// 处理位置更新
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else { return }

        // 检查精度
        if location.horizontalAccuracy > accuracyThreshold || location.horizontalAccuracy < 0 {
            logger.log(
                String(format: "忽略低精度位置: 精度 %.1fm > %.1fm", location.horizontalAccuracy, accuracyThreshold),
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
        maxRecordedSpeed = max(maxRecordedSpeed, speedKmh)

        // 速度检测
        let isOverSpeed = speedKmh > speedLimit
        logger.logSpeed(speedKmh, isOverSpeed: isOverSpeed, countdown: overSpeedCountdown)

        if isOverSpeed {
            handleOverSpeed()
        } else {
            handleNormalSpeed(location: location)
        }
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
        }

        // 记录点
        pathPoints.append((location.coordinate, location.timestamp))
        lastValidLocation = location
        lastRecordTime = location.timestamp

        logger.logDistance(segmentDistance: segmentDistance, totalDistance: totalDistance)
    }

    // MARK: - Over Speed Handling

    /// 开始超速倒计时
    private func startOverSpeedCountdown() {
        countdownValue = warningDuration
        overSpeedCountdown = countdownValue
        explorationState = .overSpeedWarning(secondsRemaining: countdownValue)

        logger.log(
            String(format: "⚠️ 超速警告！当前速度 %.1f km/h，开始 %d 秒倒计时", currentSpeed, warningDuration),
            type: .warning
        )
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

        logger.log("超速倒计时: \(countdownValue) 秒", type: .warning)

        if countdownValue <= 0 {
            // 倒计时结束，检查当前速度
            if currentSpeed > speedLimit {
                // 仍然超速，探索失败
                failExploration()
            } else {
                // 速度已恢复，取消倒计时
                cancelOverSpeedCountdown()
            }
        }
    }

    /// 取消超速倒计时
    private func cancelOverSpeedCountdown() {
        overSpeedTimer?.invalidate()
        overSpeedTimer = nil
        overSpeedCountdown = nil

        if isExploring && case .overSpeedWarning = explorationState {
            explorationState = .exploring
            logger.log("✓ 速度恢复正常，取消超速倒计时", type: .success)
            logger.logStateChange(from: "overSpeedWarning", to: "exploring")
        }
    }

    /// 探索失败（超速）
    private func failExploration() {
        overSpeedTimer?.invalidate()
        overSpeedTimer = nil

        // 停止位置更新
        locationManager?.stopUpdatingLocation()

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

        let itemCount = tier.itemCount
        var rewards: [ObtainedItem] = []

        for _ in 0..<itemCount {
            let item = generateRandomItem(tier: tier)
            rewards.append(item)
        }

        logger.logReward(tier: tier, itemCount: itemCount, items: rewards)
        return rewards
    }

    /// 生成随机物品
    private func generateRandomItem(tier: RewardTier) -> ObtainedItem {
        let randomValue = Double.random(in: 0...1)

        // 根据概率确定稀有度
        let rarity: ItemRarity
        if randomValue < tier.commonProbability {
            rarity = .common
        } else if randomValue < tier.commonProbability + tier.rareProbability {
            rarity = .rare
        } else {
            rarity = .epic
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

    /// 获取指定稀有度的物品池
    private func getItemPool(for rarity: ItemRarity) -> [String] {
        switch rarity {
        case .common:
            return ["water_bottle", "canned_food", "bandage", "wood", "scrap_metal"]
        case .uncommon:
            return ["medicine", "flashlight", "rope"]
        case .rare:
            return ["first_aid_kit", "radio", "toolbox"]
        case .epic:
            return ["antibiotics", "generator_part", "gas_mask"]
        case .legendary:
            return ["rare_medicine", "military_gear"]
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

        do {
            // 保存探索会话
            let sessionId = try await saveExplorationSession(result: result, userId: userId)
            logger.log("探索会话已保存: \(sessionId)", type: .success)

            // 保存奖励物品
            if !rewards.isEmpty {
                try await saveInventoryItems(items: rewards, sessionId: sessionId, userId: userId)
                logger.log("已保存 \(rewards.count) 件物品到背包", type: .success)
            }
        } catch {
            logger.logError("保存到数据库失败", error: error)
        }
    }

    /// 保存探索会话
    private func saveExplorationSession(result: ExplorationSessionResult, userId: UUID) async throws -> String {
        let dateFormatter = ISO8601DateFormatter()

        // 转换路径为 JSON
        let pathJSON = result.path.map { point in
            [
                "lat": point.coordinate.latitude,
                "lon": point.coordinate.longitude,
                "timestamp": dateFormatter.string(from: point.timestamp)
            ] as [String: Any]
        }

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

    /// 保存背包物品
    private func saveInventoryItems(items: [ObtainedItem], sessionId: String, userId: UUID) async throws {
        for item in items {
            let itemData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "item_id": .string(item.itemId),
                "quantity": .integer(item.quantity),
                "quality": item.quality != nil ? .string(item.quality!.rawValue) : .null,
                "obtained_from": .string("exploration"),
                "exploration_session_id": .string(sessionId)
            ]

            try await supabase
                .from("inventory_items")
                .insert(itemData)
                .execute()
        }
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
}
