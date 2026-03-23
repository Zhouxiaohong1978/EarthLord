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

    /// 速度警告阈值 (km/h) - 与圈地系统一致
    private let explorationSpeedWarningThreshold: Double = 15.0

    /// 速度暂停阈值 (km/h) - 超过此值跳过采点并计入超速次数
    private let explorationSpeedPauseThreshold: Double = 20.0

    /// 连续超速次数达到此值时自动停止探索
    private let explorationConsecutiveOverspeedLimit: Int = 3

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

    private static let nearbyPOIsKey = "exploration_nearby_pois"
    private static let scavengedPOITimesKey = "exploration_scavenged_times"

    /// 当前探索会话的POI列表（自动持久化）
    @Published var nearbyPOIs: [POI] = [] {
        didSet { savePOIsToDisk() }
    }

    /// 当前可见的POI：探索开始即固定显示所有目标废墟
    var visiblePOIs: [POI] { nearbyPOIs }

    /// 当前接近的POI（触发弹窗）
    @Published var currentProximityPOI: POI?

    /// 是否显示接近弹窗
    @Published var showProximityPopup: Bool = false

    /// 建筑物内停留提醒（1/3、2/3、3/3），速度恢复后清除
    @Published var buildingEntryWarning: String?

    /// 自动停止原因（用于显示给用户）
    @Published var autoStopMessage: String?

    /// 接近POI但步行不足500m时的提示（POI名 + 剩余距离），3秒后自动清除（已废弃，保留兼容）
    @Published var poiApproachHint: (name: String, remaining: Int)?

    /// 搜刮成功后的下一个POI导引提示（POI名 + 距离），5秒后自动清除
    @Published var nextPOIHint: (name: String, distance: Int)?

    /// POI搜刮时间记录（坐标Key → 最后搜刮时间，跨会话持久化）
    /// Key格式："lat,lon"（小数点后4位，约11米精度）
    @Published var scavengedPOITimes: [String: Date] = [:] {
        didSet { saveScavengedTimesToDisk() }
    }

    /// 搜刮结果（用于展示给用户确认）
    @Published var scavengeResult: ScavengeResult?

    /// 是否显示搜刮结果弹窗
    @Published var showScavengeResult: Bool = false

    /// 今日已探索次数
    @Published var todayExplorationCount: Int = 0

    /// 今日探索次数限制（nil = 无限）
    var dailyExplorationLimit: Int? {
        SubscriptionManager.shared.dailyExplorationLimit
    }

    /// 是否还能探索（未达到每日上限）
    var canStartExploration: Bool {
        guard let limit = dailyExplorationLimit else { return true }
        return todayExplorationCount < limit
    }

    /// 剩余探索次数（nil = 无限）
    var remainingExplorations: Int? {
        guard let limit = dailyExplorationLimit else { return nil }
        return max(0, limit - todayExplorationCount)
    }

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

    /// 探索起点位置（用于 POI 距离过滤）
    private var explorationStartLocation: CLLocation?

    /// 当前连续超速计数（与圈地系统一致）
    private var explorationConsecutiveOverspeedCount: Int = 0

    /// 当前区域的密度质量修正系数（影响搜刮物品稀有率）
    private var currentDensityModifier: Double = 0.0

    /// 超速计时器（保留兼容，新逻辑不再使用）
    private var overSpeedTimer: Timer?

    /// 建筑物停留宽限期计时器（3次提醒后1分钟内未恢复则自动停止）
    private var buildingEntryGraceTimer: Timer?

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

    /// 探索期间升级后的有效档位（用于距离奖励倍率计算）
    private var explorationEffectiveTier: SubscriptionTier?

    /// Combine 订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        loadPOIsFromDisk()
        loadScavengedTimesFromDisk()
        setupLocationManager()
        observeSubscriptionTier()
    }

    // MARK: - Setup

    /// 设置位置管理器
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = minimumRecordDistance
        // 注意：allowsBackgroundLocationUpdates 延迟到 startExploration() 时才设置，
        // 避免未启动的 CLLocationManager 干扰领地追踪的 GPS 回调

        logger.log("位置管理器初始化完成", type: .info)
    }

    // MARK: - 订阅档位监听

    /// 监听订阅档位升级，探索中自动追加 POI 并锁定奖励倍率
    private func observeSubscriptionTier() {
        SubscriptionManager.shared.$currentTier
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTier in
                guard let self, self.isExploring else { return }
                // 锁定新档位用于距离奖励计算
                self.explorationEffectiveTier = newTier
                // 追加新档位对应的额外废墟
                Task { @MainActor [weak self] in
                    await self?.appendPOIsForUpgrade(newTier: newTier)
                }
            }
            .store(in: &cancellables)
    }

    /// 在探索中订阅升级后，追加额外废墟（不替换已有的）
    private func appendPOIsForUpgrade(newTier: SubscriptionTier) async {
        let activeCount = nearbyPOIs.filter { !isCoolingDown($0) }.count
        let toAdd = newTier.poiCount - activeCount
        guard toAdd > 0 else { return }
        guard let startLoc = explorationStartLocation else { return }

        logger.log("🎖️ 订阅升级至 \(newTier.rawValue)，当前 \(activeCount) 个废墟，追加 \(toAdd) 个", type: .info)

        let center = startLoc.coordinate
        let newRadius = newTier.explorationRadius * 1000
        let searchDiameter = newRadius * 2 + 500

        // 已有 POI 的坐标 Key，用于去重
        let existingKeys = Set(nearbyPOIs.map { coordKey(for: $0.coordinate) })
        var seenCoordinates = existingKeys

        let languageManager = LanguageManager.shared
        let isEnglish = languageManager.currentLocale == "en"
        let searchQueries: [(query: String, type: POIType)] = isEnglish ? [
            ("supermarket", .supermarket), ("convenience store", .supermarket),
            ("hospital", .hospital), ("pharmacy", .pharmacy),
            ("gas station", .gasStation), ("restaurant", .restaurant)
        ] : [
            ("超市", .supermarket), ("便利店", .supermarket),
            ("医院", .hospital), ("药店", .pharmacy),
            ("加油站", .gasStation), ("餐厅", .restaurant)
        ]

        var candidates: [POI] = []

        for (query, poiType) in searchQueries {
            guard candidates.count < toAdd * 3 else { break }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: searchDiameter,
                longitudinalMeters: searchDiameter
            )
            do {
                let response = try await MKLocalSearch(request: request).start()
                for mapItem in response.mapItems {
                    let key = String(format: "%.4f,%.4f",
                                     mapItem.placemark.coordinate.latitude,
                                     mapItem.placemark.coordinate.longitude)
                    guard !seenCoordinates.contains(key) else { continue }
                    let poiLoc = CLLocation(latitude: mapItem.placemark.coordinate.latitude,
                                            longitude: mapItem.placemark.coordinate.longitude)
                    let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    let dist = origin.distance(from: poiLoc)
                    guard dist >= 500 && dist <= newRadius else { continue }
                    seenCoordinates.insert(key)
                    candidates.append(convertMapItemToPOI(mapItem, overrideType: poiType))
                }
            } catch {
                logger.logError("追加POI搜索失败: \(query)", error: error)
            }
        }

        let newPOIs = Array(candidates.prefix(toAdd))
        guard !newPOIs.isEmpty else {
            logger.log("⚠️ 未找到可追加的废墟", type: .warning)
            return
        }

        nearbyPOIs.append(contentsOf: newPOIs)

        // 仅为新 POI 注册地理围栏
        if let lm = locationManager {
            for poi in newPOIs {
                let region = CLCircularRegion(center: poi.coordinate, radius: 50.0, identifier: poi.id.uuidString)
                region.notifyOnEntry = true
                region.notifyOnExit = false
                lm.startMonitoring(for: region)
            }
        }

        logger.log("✅ 已追加 \(newPOIs.count) 个废墟，当前共 \(nearbyPOIs.count) 个", type: .success)
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() {
        logger.log("========== 开始探索请求 ==========", type: .info)

        guard !isExploring else {
            logger.logError("探索已在进行中，无法重复开始")
            return
        }

        // 检查每日探索次数限制
        refreshTodayExplorationCount()
        guard canStartExploration else {
            logger.logError("今日探索次数已达上限(\(todayExplorationCount)/\(dailyExplorationLimit ?? 0))，订阅可解锁无限次数")
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
        explorationEffectiveTier = nil  // 清除上次会话的档位记录

        // 保存探索起点（用于 POI 距离过滤，避免 GPS 漂移影响）
        explorationStartLocation = locationManager.location
        explorationConsecutiveOverspeedCount = 0

        // 开始探索
        isExploring = true
        explorationState = .exploring
        startTime = Date()

        // 启用后台定位（探索时才需要，避免干扰领地追踪）
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // 开始位置更新
        locationManager.startUpdatingLocation()
        logger.log("已启动位置更新服务", type: .info)

        // 开始时长计时
        startDurationTimer()
        logger.log("已启动探索计时器", type: .info)

        logger.logExplorationStart()
        logger.logStateChange(from: "idle", to: "exploring")
        logger.log("速度警告阈值: \(explorationSpeedWarningThreshold) km/h, 暂停阈值: \(explorationSpeedPauseThreshold) km/h", type: .info)

        // 搜索附近POI（使用已保存的起点，确保距离过滤一致）
        Task {
            let startCoord = explorationStartLocation?.coordinate ?? locationManager.location?.coordinate
            guard let coord = startCoord else { return }
            // 先刷新订阅状态，避免 currentTier 在订阅加载完成前读到 .free（竞态条件）
            await SubscriptionManager.shared.refreshSubscriptionStatus()
            await searchNearbyPOIs(center: coord)
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

        // 停止位置更新，并重置后台定位设置
        locationManager?.stopUpdatingLocation()
        locationManager?.allowsBackgroundLocationUpdates = false
        logger.log("已停止位置更新服务", type: .info)

        // 停止计时器
        stopDurationTimer()
        cancelOverSpeedCountdown()

        // 清理POI和地理围栏（保留冷却记录，跨会话持久化）
        cleanupGeofences()
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

        // 增加今日探索次数
        if !cancelled {
            incrementTodayExplorationCount()
        }

        // 异步保存会话到数据库（物品等用户确认后再保存）+ 体征消耗
        Task {
            await saveExplorationToDatabase(result: result, rewards: [])
            if !cancelled {
                let distanceKm = totalDistance / 1000.0
                await PhysiqueManager.shared.consumeByExploration(distanceKm: distanceKm)
            }
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

        // 重置起点和超速计数
        explorationStartLocation = nil
        explorationConsecutiveOverspeedCount = 0
        LocationManager.shared.speedWarning = nil
        LocationManager.shared.isOverSpeed = false

        // 重置建筑物停留状态
        buildingEntryGraceTimer?.invalidate()
        buildingEntryGraceTimer = nil
        buildingEntryWarning = nil
        autoStopMessage = nil

        // 清除旧POI列表和地理围栏，新探索从当前位置重新加载
        nearbyPOIs.removeAll()
        cleanupGeofences()
        currentProximityPOI = nil
        showProximityPopup = false

        logger.log("探索状态已重置", type: .info)
    }

    // MARK: - Daily Exploration Count

    /// UserDefaults key for today's exploration count
    private static let dailyCountKey = "exploration_daily_count"
    private static let dailyCountDateKey = "exploration_daily_count_date"

    /// 刷新今日探索次数（如果日期变了则重置）
    func refreshTodayExplorationCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = UserDefaults.standard.object(forKey: Self.dailyCountDateKey) as? Date ?? .distantPast
        let savedDay = Calendar.current.startOfDay(for: savedDate)

        if today != savedDay {
            // 新的一天，重置计数
            UserDefaults.standard.set(0, forKey: Self.dailyCountKey)
            UserDefaults.standard.set(today, forKey: Self.dailyCountDateKey)
            todayExplorationCount = 0
        } else {
            todayExplorationCount = UserDefaults.standard.integer(forKey: Self.dailyCountKey)
        }
    }

    /// 增加今日探索次数
    private func incrementTodayExplorationCount() {
        refreshTodayExplorationCount()
        todayExplorationCount += 1
        UserDefaults.standard.set(todayExplorationCount, forKey: Self.dailyCountKey)
        logger.log("今日探索次数: \(todayExplorationCount)/\(dailyExplorationLimit.map { String($0) } ?? "∞")", type: .info)
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

        // 速度检测：高速可能是进入建筑物导致GPS漂移，不立即停止，改为分级提醒
        logger.logSpeed(speedKmh, isOverSpeed: speedKmh > explorationSpeedWarningThreshold, countdown: overSpeedCountdown)

        if speedKmh < explorationSpeedWarningThreshold {
            // 速度恢复正常：重置计数、取消宽限期、清除提醒，继续记录
            if explorationConsecutiveOverspeedCount > 0 {
                explorationConsecutiveOverspeedCount = 0
                buildingEntryGraceTimer?.invalidate()
                buildingEntryGraceTimer = nil
                buildingEntryWarning = nil
                logger.log("速度已恢复正常，取消建筑物停留计时", type: .info)
            }
            LocationManager.shared.speedWarning = nil
            LocationManager.shared.isOverSpeed = false
            handleNormalSpeed(location: location)

        } else if speedKmh > explorationSpeedPauseThreshold {
            // 高速（GPS漂移）：分级提醒，不跳点也不停止
            LocationManager.shared.isOverSpeed = true
            // 仅在宽限期未激活时才递增计数
            if buildingEntryGraceTimer == nil {
                explorationConsecutiveOverspeedCount += 1
            }
            logger.log(String(format: "⚠️ GPS漂移/高速: %.1f km/h，连续第 %d 次", speedKmh, explorationConsecutiveOverspeedCount), type: .warning)
            handleBuildingEntryWarning(count: explorationConsecutiveOverspeedCount)

        } else {
            // 15~20 km/h：同样视为建筑物停留，分级提醒
            LocationManager.shared.isOverSpeed = true
            if buildingEntryGraceTimer == nil {
                explorationConsecutiveOverspeedCount += 1
            }
            logger.log(String(format: "⚠️ 速度较快: %.1f km/h，连续第 %d 次", speedKmh, explorationConsecutiveOverspeedCount), type: .warning)
            handleBuildingEntryWarning(count: explorationConsecutiveOverspeedCount)
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

    /// 取消超速倒计时（兼容旧状态清理）
    private func cancelOverSpeedCountdown() {
        overSpeedTimer?.invalidate()
        overSpeedTimer = nil
        overSpeedCountdown = nil

        if isExploring, case .overSpeedWarning = explorationState {
            explorationState = .exploring
        }
    }

    /// 探索失败（超速，保留供旧路径调用）
    private func failExploration() {
        logger.log("🛑 ========== 探索失败处理 ==========", type: .error)
        logger.log("失败原因: 连续超速自动停止", type: .error)
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

        // 优先使用探索期间捕获的档位（应对 StoreKit 异步验证延迟）
        let subscriptionTier = explorationEffectiveTier ?? SubscriptionManager.shared.currentTier
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

        // 建造材料类给予随机数量，生存消耗品保持1个
        let quantity = itemDropQuantity(for: selectedItem, tier: tier)

        return ObtainedItem(
            itemId: selectedItem,
            quantity: quantity,
            quality: quality
        )
    }

    /// 根据物品类型和探索档位决定掉落数量
    private func itemDropQuantity(for itemId: String, tier: RewardTier) -> Int {
        switch itemId {
        case "wood", "stone":
            return tier == .bronze ? Int.random(in: 3...6) : Int.random(in: 5...10)
        case "scrap_metal", "nails", "rope", "cloth":
            return tier == .bronze ? Int.random(in: 2...4) : Int.random(in: 3...7)
        default:
            return 1
        }
    }

    /// 获取指定稀有度的物品池（GDD对齐，所有等级包含建造材料）
    private func getItemPool(for rarity: ItemRarity) -> [String] {
        switch rarity {
        case .common:
            // 生存基础 + 核心建造材料（木头/石头）
            return ["water_bottle", "canned_food", "bread", "bandage", "wood", "stone", "cloth"]
        case .uncommon:
            // 进阶建造材料 + 基础工具 + 玻璃（废墟窗户/橱柜）
            return ["scrap_metal", "nails", "rope", "seeds", "medicine", "tool", "glass"]
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
    /// 传入的 items 为玩家已勾选确认收取的物品，不存在溢出情况
    private func saveRewardsToInventory(items: [ObtainedItem], sessionId: String?) async {
        var failedItems: [ObtainedItem] = []

        for item in items {
            do {
                try await InventoryManager.shared.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "探索",
                    sessionId: sessionId?.isEmpty == false ? sessionId : nil,
                    customName: item.customName
                )
                logger.log("✅ 物品已添加到背包: \(item.itemId) x\(item.quantity)", type: .success)
            } catch {
                logger.logError("❌ 添加物品到背包失败: \(item.itemId)", error: error)
                failedItems.append(item)
            }
        }

        // 网络失败的物品加入离线队列，待网络恢复后同步
        if !failedItems.isEmpty {
            logger.log("⚠️ 有 \(failedItems.count) 件物品保存失败，加入离线队列", type: .warning)
            for item in failedItems {
                OfflineSyncManager.shared.addPendingItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    obtainedFrom: "探索",
                    sessionId: sessionId?.isEmpty == false ? sessionId : nil
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

        // ====== POI数量由订阅档位决定，密度影响物资质量 ======
        let targetPOICount = SubscriptionManager.shared.currentTier.poiCount
        logger.log("📦 订阅档位: \(SubscriptionManager.shared.currentTier.rawValue) - 显示 \(targetPOICount) 个POI", type: .info)

        do {
            let densityResult = try await PlayerDensityService.shared.queryNearbyPlayers(
                latitude: center.latitude,
                longitude: center.longitude
            )
            let level = densityResult.densityLevel
            currentDensityModifier = level.rareProbabilityModifier
            let modifierText = currentDensityModifier >= 0 ? "+\(Int(currentDensityModifier * 100))%" : "\(Int(currentDensityModifier * 100))%"
            logger.log("👥 附近玩家: \(densityResult.nearbyCount)人, 密度: \(level.rawValue) - 物资质量修正: \(modifierText)", type: .info)
        } catch {
            currentDensityModifier = 0.0
            logger.logError("玩家密度查询失败，使用默认物资质量", error: error)
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
            ("coffee", .restaurant),
            ("phone store", .electronics),
            ("electronics store", .electronics),
            ("mobile shop", .electronics)
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
            ("咖啡厅", .restaurant),
            ("手机店", .electronics),
            ("电器店", .electronics),
            ("数码店", .electronics)
        ]

        // 获取探索范围（基于订阅档位：1.0/2.0/3.0 km）
        let explorationRadius = SubscriptionManager.shared.explorationRadius * 1000 // 转换为米
        // 搜索直径 = 探索半径 × 2 + 500m 缓冲，确保能覆盖距起点 500m~explorationRadius 的 POI
        let searchDiameter = explorationRadius * 2 + 500

        var allResults: [POI] = []
        let maxPerQuery = 10  // 每个关键词最多取10个，确保500m~2km范围内有足够候选
        var seenCoordinates: Set<String> = []  // 用于去重

        for (query, poiType) in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: searchDiameter,
                longitudinalMeters: searchDiameter
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

        // 用探索起点计算距离（explorationStartLocation 已在 startExploration 中保存）
        let distanceOrigin = explorationStartLocation ?? userLocation

        for poi in allResults {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = distanceOrigin.distance(from: poiLocation)

            // 只保留距探索起点 500m ~ explorationRadius 范围内、且未在冷却中的POI
            // 最小距离 500m：鼓励用户步行前往，同时足够覆盖 WGS84/GCJ02 坐标偏移
            guard distance >= 500 && distance <= explorationRadius && !isCoolingDown(poi) else { continue }

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

        // 第二轮：如果还有配额，从有POI的象限补充（优先选取距离适中的POI，避免选出最近的）
        if balancedResults.count < targetPOICount {
            let remaining = targetPOICount - balancedResults.count
            let allRemaining = quadrants.values.flatMap { $0 }.filter { poi in
                !balancedResults.contains(where: { $0.id == poi.id })
            }
            // 按距离适中排序：优先选取在有效范围中段的POI（避免总选最近的）
            let idealDistance = (500.0 + explorationRadius) / 2
            let sortedRemaining = allRemaining.sorted { poi1, poi2 in
                let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
                let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
                let d1 = abs(userLocation.distance(from: loc1) - idealDistance)
                let d2 = abs(userLocation.distance(from: loc2) - idealDistance)
                return d1 < d2
            }
            balancedResults.append(contentsOf: sortedRemaining.prefix(remaining))
            logger.log("📊 基础配额不足，从剩余POI中补充 \(min(remaining, sortedRemaining.count)) 个（理想距离: \(String(format: "%.0f", idealDistance))m）", type: .info)
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

    // MARK: - 持久化

    private func savePOIsToDisk() {
        guard let data = try? JSONEncoder().encode(nearbyPOIs) else { return }
        UserDefaults.standard.set(data, forKey: Self.nearbyPOIsKey)
    }

    private func loadPOIsFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.nearbyPOIsKey),
              let pois = try? JSONDecoder().decode([POI].self, from: data) else { return }
        nearbyPOIs = pois
    }

    private func saveScavengedTimesToDisk() {
        let dict = scavengedPOITimes.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(dict, forKey: Self.scavengedPOITimesKey)
    }

    private func loadScavengedTimesFromDisk() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.scavengedPOITimesKey) as? [String: Double] else { return }
        scavengedPOITimes = dict.mapValues { Date(timeIntervalSince1970: $0) }
    }

    /// POI坐标Key（用于跨会话稳定识别同一物理地点）
    func coordKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    /// 判断某POI是否处于冷却中
    func isCoolingDown(_ poi: POI) -> Bool {
        let key = coordKey(for: poi.coordinate)
        guard let lastTime = scavengedPOITimes[key] else { return false }
        let cooldownSeconds = SubscriptionManager.shared.currentTier.poiCooldownHours * 3600
        return Date().timeIntervalSince(lastTime) < cooldownSeconds
    }

    /// 返回某POI的冷却剩余秒数（0表示已就绪）
    func cooldownRemaining(_ poi: POI) -> TimeInterval {
        let key = coordKey(for: poi.coordinate)
        guard let lastTime = scavengedPOITimes[key] else { return 0 }
        let cooldownSeconds = SubscriptionManager.shared.currentTier.poiCooldownHours * 3600
        return max(0, cooldownSeconds - Date().timeIntervalSince(lastTime))
    }

    /// 清理所有地理围栏（保留 nearbyPOIs 供列表展示）
    private func cleanupGeofences() {
        guard let locationManager = locationManager else { return }

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        logger.log("已清理地理围栏", type: .info)
    }

    /// 处理进入POI范围
    @MainActor
    private func handlePOIProximity(regionId: String) {
        guard let poiId = UUID(uuidString: regionId),
              let poi = nearbyPOIs.first(where: { $0.id == poiId }),
              !isCoolingDown(poi),
              currentProximityPOI == nil, !showProximityPopup else {
            return
        }

        // 验证实际距离：地理围栏可能在冷启动时对旧区域误触发，需二次确认
        if let rawLocation = locationManager?.location {
            let gcj02 = CoordinateConverter.wgs84ToGcj02(rawLocation.coordinate)
            let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)
            let poiLoc = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userLoc.distance(from: poiLoc)
            guard distance <= 150.0 else {
                logger.log("⚠️ 地理围栏触发但实际距离 \(String(format: "%.0f", distance))m，跳过: \(poi.name)", type: .warning)
                return
            }
        }

        logger.log("进入废墟50m范围: \(poi.name)", type: .info)

        currentProximityPOI = poi
        showProximityPopup = true
    }

    /// 处理建筑物停留提醒（分级：1/3、2/3、3/3，第3次启动1分钟宽限期）
    @MainActor
    private func handleBuildingEntryWarning(count: Int) {
        switch count {
        case 1:
            buildingEntryWarning = String(localized: "exploration.building.warning1")
            logger.log("建筑物停留提醒 1/3", type: .warning)
        case 2:
            buildingEntryWarning = String(localized: "exploration.building.warning2")
            logger.log("建筑物停留提醒 2/3", type: .warning)
        case 3 where buildingEntryGraceTimer == nil:
            buildingEntryWarning = String(localized: "exploration.building.warning3")
            logger.log("建筑物停留提醒 3/3，启动1分钟宽限期", type: .warning)
            // 启动1分钟倒计时，超时自动停止探索（无距离奖励）
            buildingEntryGraceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isExploring else { return }
                    self.logger.log("建筑物停留超过1分钟，自动停止探索", type: .error)
                    self.buildingEntryWarning = nil
                    self.buildingEntryGraceTimer = nil
                    self.autoStopMessage = String(localized: "exploration.building.auto_stopped")
                    self.stopExploration(cancelled: true)
                }
            }
        default:
            break
        }
    }

    /// 搜刮成功后提示最近的下一个可搜刮POI
    @MainActor
    func showNextPOIHintAfterScavenge(scavengedPOI: POI) {
        guard let userLocation = locationManager?.location else { return }
        let gcj02 = CoordinateConverter.wgs84ToGcj02(userLocation.coordinate)
        let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)

        // 找出未冷却的其他POI中距离最近的一个
        let next = nearbyPOIs
            .filter { $0.id != scavengedPOI.id && !isCoolingDown($0) }
            .min(by: {
                let d1 = userLoc.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))
                let d2 = userLoc.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
                return d1 < d2
            })

        guard let nextPOI = next else { return }
        let distance = Int(userLoc.distance(from: CLLocation(latitude: nextPOI.coordinate.latitude, longitude: nextPOI.coordinate.longitude)))
        nextPOIHint = (name: nextPOI.name, distance: distance)
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            nextPOIHint = nil
        }
    }

    /// 主动检测是否接近POI（解决地理围栏"已在范围内"不触发的问题）
    private func checkPOIProximity(location: CLLocation) {
        // 已有弹窗显示时不检测
        guard currentProximityPOI == nil, !showProximityPopup else { return }

        // 将GPS坐标（WGS-84）转换为GCJ-02，与MapKit返回的POI坐标对比
        let gcj02Coord = CoordinateConverter.wgs84ToGcj02(location.coordinate)
        let userLocationGCJ02 = CLLocation(latitude: gcj02Coord.latitude, longitude: gcj02Coord.longitude)

        for poi in nearbyPOIs {
            // 跳过冷却中的POI
            guard !isCoolingDown(poi) else { continue }

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

        // 以坐标为Key记录搜刮时间，跨会话持久化
        scavengedPOITimes[coordKey(for: poi.coordinate)] = Date()

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

        // POI 搜刮不属于探索会话，sessionId 传 nil 避免触发外键约束
        let sessionId: String? = nil

        // 创建搜刮结果，等待用户确认
        scavengeResult = ScavengeResult(
            poi: poi,
            items: aiItems,
            sessionId: sessionId ?? "",
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

    /// 根据危险等级确定稀有度（叠加区域密度修正）
    /// currentDensityModifier > 0：独行者区域，物资丰富，稀有率提升
    /// currentDensityModifier < 0：热门区域，物资匮乏，稀有率下降
    private func determineRarityByDangerLevel(_ dangerLevel: Int) -> String {
        // 将密度修正叠加到随机值：正修正 → 随机值偏高 → 更易命中稀有档
        let raw = Double.random(in: 0...1)
        let randomValue = min(1.0, max(0.0, raw + currentDensityModifier))

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
            case .electronics:
                return [
                    ("电路板残片", "从废弃手机里拆下的电路板，里面还有可用的元件。", "material"),
                    ("旧手机", "屏碎了但主板完好，能拆出不少有用的零件。", "material"),
                    ("充电宝", "电量不足10%，但电芯还能用。", "tool")
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

    /// 确认搜刮结果，将玩家勾选的物品添加到背包
    func confirmScavengeResult(selectedIds: Set<UUID>) async {
        guard let result = scavengeResult else {
            logger.logError("没有待确认的搜刮结果")
            return
        }

        let selectedItems = result.items.filter { selectedIds.contains($0.id) }
        logger.log("用户确认搜刮结果，保存 \(selectedItems.count)/\(result.items.count) 件物品到背包", type: .info)

        // 立即将该POI状态更新为已搜空（地图上马上变灰）
        if let index = nearbyPOIs.firstIndex(where: { $0.id == result.poi.id }) {
            nearbyPOIs[index].status = .looted
        }

        // 先关闭弹窗（避免网络等待期间重复点击）并重置接近状态（允许检测下一个POI）
        let scavengedPOI = result.poi
        scavengeResult = nil
        showScavengeResult = false
        currentProximityPOI = nil

        // 保存物品（后台进行，视图已关闭）
        let obtainedItems = selectedItems.map { $0.toObtainedItem() }
        await saveRewardsToInventory(items: obtainedItems, sessionId: result.sessionId)

        logger.log("物品已保存到背包", type: .success)

        // 提示玩家最近的下一个可搜刮POI
        showNextPOIHintAfterScavenge(scavengedPOI: scavengedPOI)
    }

    /// 放弃搜刮结果（用户不想要这些物品）
    func discardScavengeResult() {
        logger.log("用户放弃搜刮结果", type: .info)
        scavengeResult = nil
        showScavengeResult = false
        currentProximityPOI = nil
    }

    /// 确认探索距离奖励，将玩家勾选的物品添加到背包
    func confirmExplorationRewards(selectedIds: Set<UUID>) async {
        guard let result = explorationResult else {
            logger.logError("没有待确认的探索奖励结果")
            return
        }
        let selectedItems = result.obtainedItems.filter { selectedIds.contains($0.id) }
        logger.log("用户确认探索奖励，保存 \(selectedItems.count)/\(result.obtainedItems.count) 件物品到背包", type: .info)
        await saveRewardsToInventory(items: selectedItems, sessionId: nil)
    }
}
