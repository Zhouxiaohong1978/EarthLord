//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取和权限管理
//

import Foundation
import CoreLocation
import Combine  // @Published 需要这个框架

// MARK: - LocationManager 定位管理器

/// 管理 GPS 定位和权限请求
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation: Bool = false

    // MARK: - 路径追踪 Published Properties

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否已闭合（Day16 圈地判定会用）
    @Published var isPathClosed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String?

    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager: CLLocationManager

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    /// 最小记录距离（米）- 移动超过此距离才记录新点
    private let minimumRecordDistance: CLLocationDistance = 10.0

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 闭环距离阈值（米）- 当前位置距起点小于此值则认为闭环
    private let closureDistanceThreshold: CLLocationDistance = 30.0

    /// 最少路径点数 - 闭环至少需要的点数
    private let minimumPathPoints: Int = 10

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 最小紧凑度（面积/边界框面积的百分比）
    /// 用于检测「原路返回」等细长形状
    /// 正常多边形应 > 25%，圆形约 78.5%，正方形 100%
    private let minimumCompactnessRatio: Double = 25.0

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度暂停阈值（km/h）
    private let speedPauseThreshold: Double = 30.0

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否权限状态未确定
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 当前路径点数
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        // 获取初始授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米就更新（追踪时需要更频繁）
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        // 清除之前的错误
        locationError = nil

        // 请求"使用App期间"权限
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始获取位置更新
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未授权定位权限"
            return
        }

        locationError = nil
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    /// 停止位置更新
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置更新
    func requestLocation() {
        guard isAuthorized else {
            locationError = "未授权定位权限"
            return
        }

        locationError = nil
        locationManager.requestLocation()
    }

    // MARK: - 路径追踪 Public Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未授权定位权限，无法追踪"
            return
        }

        // 清除之前的路径
        clearPath()

        // 标记开始追踪
        isTracking = true
        isPathClosed = false

        // 确保正在更新位置
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果有当前位置，立即记录第一个点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.recordPathPoint()
            }
        }

        print("📍 开始路径追踪")

        // 添加日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    /// - Parameter clearAllState: 是否清除所有状态（上传成功后应设为 true）
    func stopPathTracking(clearAllState: Bool = false) {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记停止追踪
        isTracking = false

        print("📍 停止路径追踪，共记录 \(pathCoordinates.count) 个点")

        // 添加日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 如果需要清除所有状态（上传成功后）
        if clearAllState {
            pathCoordinates.removeAll()
            pathUpdateVersion += 1
            isPathClosed = false
            speedWarning = nil
            isOverSpeed = false
            lastLocationTimestamp = nil
            territoryValidationPassed = false
            territoryValidationError = nil
            calculatedArea = 0
            TerritoryLogger.shared.log("已重置所有圈地状态", type: .info)
        }
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    // MARK: - 路径追踪 Private Methods

    /// 定时器回调 - 判断是否记录新点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else { return }

        // 如果是第一个点，直接记录
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录第一个点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return
        }

        // ⭐ 速度检测 - 超速时不记录该点
        if !validateMovementSpeed(newLocation: location) {
            return
        }

        // 计算与上一个点的距离
        guard let lastCoordinate = pathCoordinates.last else { return }

        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 只有移动超过最小距离才记录新点
        if distance >= minimumRecordDistance {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录新点 #\(pathCoordinates.count): 距上个点 \(String(format: "%.1f", distance))米")

            // 添加日志
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

            // ⭐ 闭环检测 - 每次记录新点后检测是否闭环
            checkPathClosure()
        }
    }

    // MARK: - 闭环检测

    /// 检测路径是否闭合
    private func checkPathClosure() {
        // 如果已经闭环，不再重复检测
        if isPathClosed {
            return
        }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔍 闭环检测：点数不足 (\(pathCoordinates.count)/\(minimumPathPoints))")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        // 距离小于阈值则闭环成功
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ 闭环检测成功！距起点 \(String(format: "%.1f", distanceToStart)) 米，共 \(pathCoordinates.count) 个点")

            // 添加日志 - 闭环成功
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m", type: .success)

            // ⭐ 闭环成功后自动停止追踪
            stopPathTracking()

            // ⭐ 闭环成功后自动进行领地验证
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage
        } else {
            print("🔍 闭环检测：距起点 \(String(format: "%.1f", distanceToStart)) 米（需要 ≤ \(closureDistanceThreshold) 米）")

            // 添加日志 - 距离信息
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distanceToStart))m (需≤30m)", type: .info)
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度是否合理
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 获取上次时间戳
        guard let lastTimestamp = lastLocationTimestamp else {
            // 第一次记录，无法计算速度
            return true
        }

        // 获取上个点
        guard let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算时间差（秒）
        let timeDelta = Date().timeIntervalSince(lastTimestamp)
        guard timeDelta > 0 else {
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算速度（km/h）
        let speedKmh = (distance / timeDelta) * 3.6

        // 清除之前的警告
        if speedKmh < speedWarningThreshold {
            speedWarning = nil
            isOverSpeed = false
        }

        // 检查是否超过暂停阈值（30 km/h）
        if speedKmh > speedPauseThreshold {
            speedWarning = "移动速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，已停止追踪"
            isOverSpeed = true
            stopPathTracking()
            print("⚠️ 速度超限：\(String(format: "%.1f", speedKmh)) km/h > \(speedPauseThreshold) km/h，停止追踪")

            // 添加日志 - 超速停止
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            return false
        }

        // 检查是否超过警告阈值（15 km/h）
        if speedKmh > speedWarningThreshold {
            speedWarning = "移动速度较快 (\(String(format: "%.1f", speedKmh)) km/h)，请放慢速度"
            isOverSpeed = true
            print("⚠️ 速度警告：\(String(format: "%.1f", speedKmh)) km/h > \(speedWarningThreshold) km/h")

            // 添加日志 - 速度警告
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            return true  // 警告但继续记录
        }

        return true
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）
    /// - Returns: 路径总长度
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（平面近似，适用于小区域）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        // 检查点数是否足够
        let pointCount = pathCoordinates.count
        guard pointCount >= 3 else {
            TerritoryLogger.shared.log("面积计算: 点数不足 (\(pointCount)个)，返回0", type: .warning)
            return 0
        }

        // ⭐ 关键修复：创建闭合路径（将起点添加到末尾）
        // 这样鞋带公式不需要用"虚拟边"连接最后一点到起点
        var closedPath = pathCoordinates
        if let firstPoint = pathCoordinates.first,
           let lastPoint = pathCoordinates.last {
            // 计算最后一点到起点的距离
            let lastLoc = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let firstLoc = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
            let gapDistance = lastLoc.distance(from: firstLoc)

            // 如果最后一点不在起点附近（距离 > 1米），添加起点到末尾形成闭合
            if gapDistance > 1.0 {
                closedPath.append(firstPoint)
                TerritoryLogger.shared.log("面积计算: 路径未闭合(缺口\(String(format: "%.1f", gapDistance))m)，已添加起点闭合", type: .info)
            }
        }

        TerritoryLogger.shared.log("面积计算: 开始，原始\(pointCount)个点，闭合后\(closedPath.count)个点", type: .info)

        // 1. 计算多边形质心（中心点）- 使用闭合路径（不含重复的起点）
        var sumLat: Double = 0
        var sumLon: Double = 0
        for coord in pathCoordinates {  // 使用原始路径计算质心
            sumLat += coord.latitude
            sumLon += coord.longitude
        }
        let centroidLat = sumLat / Double(pointCount)
        let centroidLon = sumLon / Double(pointCount)

        // 打印质心信息
        TerritoryLogger.shared.log("面积计算: 质心(\(String(format: "%.6f", centroidLat)), \(String(format: "%.6f", centroidLon)))", type: .info)

        // 2. 经纬度转米的换算系数
        // 1度纬度 ≈ 111,320 米
        // 1度经度 ≈ 111,320 * cos(纬度) 米（纬度需转为弧度）
        let metersPerDegreeLat: Double = 111320.0
        let latRadians = centroidLat * .pi / 180.0
        let metersPerDegreeLon: Double = 111320.0 * cos(latRadians)

        TerritoryLogger.shared.log("面积计算: 纬度弧度=\(String(format: "%.6f", latRadians)), 经度系数=\(String(format: "%.2f", metersPerDegreeLon))m/度", type: .info)

        // 3. 将闭合路径的所有点转换为相对于质心的本地坐标（米）
        var localCoords: [(x: Double, y: Double)] = []
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity

        for coord in closedPath {  // ⭐ 使用闭合路径
            let x = (coord.longitude - centroidLon) * metersPerDegreeLon
            let y = (coord.latitude - centroidLat) * metersPerDegreeLat
            localCoords.append((x: x, y: y))

            // 记录边界
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        // 打印边界信息
        let width = maxX - minX
        let height = maxY - minY
        TerritoryLogger.shared.log("面积计算: 边界 X[\(String(format: "%.1f", minX))~\(String(format: "%.1f", maxX))]m, Y[\(String(format: "%.1f", minY))~\(String(format: "%.1f", maxY))]m", type: .info)
        TerritoryLogger.shared.log("面积计算: 边界框 \(String(format: "%.1f", width))m × \(String(format: "%.1f", height))m", type: .info)

        // 4. 使用标准鞋带公式计算面积
        // Area = 0.5 * |Σ (x_i * y_{i+1} - x_{i+1} * y_i)|
        var signedArea: Double = 0
        let n = localCoords.count

        for i in 0..<(n - 1) {  // ⭐ 修改：遍历到 n-1（因为路径已闭合，不需要 % n）
            let current = localCoords[i]
            let next = localCoords[i + 1]
            signedArea += current.x * next.y - next.x * current.y
        }

        let area = abs(signedArea) / 2.0

        // 打印最终面积
        TerritoryLogger.shared.log("面积计算: 鞋带公式有符号面积=\(String(format: "%.2f", signedArea)), 最终面积=\(String(format: "%.2f", area))m²", type: .info)

        // 合理性检查：面积应该在边界框面积的合理范围内
        let boundingBoxArea = width * height
        let areaRatio = area / boundingBoxArea * 100
        TerritoryLogger.shared.log("面积计算: 占边界框\(String(format: "%.1f", areaRatio))%", type: .info)

        if areaRatio < 20 {
            TerritoryLogger.shared.log("面积计算: 警告！面积占比过低，路径可能不够饱满", type: .warning)
        }

        return area
    }

    /// 计算多边形的紧凑度（面积 / 边界框面积）
    /// - Returns: (紧凑度百分比, 边界框宽度, 边界框高度)
    private func calculatePolygonCompactness() -> (ratio: Double, width: Double, height: Double) {
        let pointCount = pathCoordinates.count
        guard pointCount >= 3 else {
            return (0, 0, 0)
        }

        // 计算质心
        var sumLat: Double = 0
        var sumLon: Double = 0
        for coord in pathCoordinates {
            sumLat += coord.latitude
            sumLon += coord.longitude
        }
        let centroidLat = sumLat / Double(pointCount)
        let centroidLon = sumLon / Double(pointCount)

        // 经纬度转米的换算系数
        let metersPerDegreeLat: Double = 111320.0
        let latRadians = centroidLat * .pi / 180.0
        let metersPerDegreeLon: Double = 111320.0 * cos(latRadians)

        // 计算边界
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity

        for coord in pathCoordinates {
            let x = (coord.longitude - centroidLon) * metersPerDegreeLon
            let y = (coord.latitude - centroidLat) * metersPerDegreeLat
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let boundingBoxArea = width * height

        guard boundingBoxArea > 0 else {
            return (0, width, height)
        }

        // 计算面积（简化版，使用已计算的 calculatedArea）
        let area = calculatedArea > 0 ? calculatedArea : calculatePolygonArea()
        let ratio = (area / boundingBoxArea) * 100

        return (ratio, width, height)
    }

    // MARK: - 自相交检测

    /// 判断两线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D,
        p4: CLLocationCoordinate2D
    ) -> Bool {
        /// CCW（逆时针）辅助函数
        /// 坐标映射：longitude = X轴，latitude = Y轴
        /// 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        func ccw(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Bool {
            // 使用 longitude 作为 X，latitude 作为 Y
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude)
                             - (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：两线段相交当且仅当
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否存在自相交
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 只跳过首尾各1条线段的比较（闭环时首尾线段端点靠近是正常的）
        // 注意：跳过太多会导致漏检中间的交叉！
        let skipHeadCount = 1
        let skipTailCount = 1

        TerritoryLogger.shared.log("自交检测: 共 \(segmentCount) 条线段，跳过首\(skipHeadCount)尾\(skipTailCount)", type: .info)

        var checkedCount = 0
        var skippedCount = 0

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 从 i+2 开始，跳过相邻线段（相邻线段共享一个顶点，必然"相交"）
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 只跳过第一条线段与最后一条线段的比较（闭环时端点靠近）
                let isFirstSegment = (i == 0)
                let isLastSegment = (j == segmentCount - 1)

                if isFirstSegment && isLastSegment {
                    skippedCount += 1
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                checkedCount += 1

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交 ✗", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 检查了\(checkedCount)对，跳过\(skippedCount)对，无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (是否有效, 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 5. 形状紧凑度检查（检测「原路返回」等细长形状）
        let compactness = calculatePolygonCompactness()
        TerritoryLogger.shared.log("紧凑度检查: \(String(format: "%.1f", compactness.ratio))% (边界框 \(String(format: "%.1f", compactness.width))m × \(String(format: "%.1f", compactness.height))m)", type: .info)

        if compactness.ratio < minimumCompactnessRatio {
            let error = "形状过于细长（紧凑度 \(String(format: "%.0f", compactness.ratio))%），请勿原路返回"
            TerritoryLogger.shared.log("紧凑度检查: \(String(format: "%.1f", compactness.ratio))% ✗ (需≥\(Int(minimumCompactnessRatio))%)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("紧凑度检查: \(String(format: "%.1f", compactness.ratio))% ✓", type: .info)

        // 全部通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            self.authorizationStatus = newStatus

            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // 授权成功，开始定位
                self.locationError = nil
                self.startUpdatingLocation()

            case .denied:
                // 用户拒绝授权
                self.locationError = "您已拒绝定位权限，无法显示您的位置"
                self.stopUpdatingLocation()
                // 如果正在追踪，也要停止
                if self.isTracking {
                    self.stopPathTracking()
                }

            case .restricted:
                // 定位受限（如家长控制）
                self.locationError = "定位功能受到限制"
                self.stopUpdatingLocation()

            case .notDetermined:
                // 尚未决定
                break

            @unknown default:
                break
            }
        }
    }

    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // 更新用户位置
            self.userLocation = location.coordinate
            self.locationError = nil

            // ⭐ 关键：更新 currentLocation，供 Timer 采点使用
            self.currentLocation = location
        }
    }

    /// 定位失败回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // 处理定位错误
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置信息"
                case .network:
                    self.locationError = "网络错误，无法定位"
                default:
                    self.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}
