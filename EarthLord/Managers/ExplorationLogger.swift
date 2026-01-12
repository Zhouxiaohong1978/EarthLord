//
//  ExplorationLogger.swift
//  EarthLord
//
//  探索功能日志管理器 - 用于调试和排查问题
//

import Foundation
import SwiftUI
import Combine

// MARK: - ExplorationLogType 探索日志类型

/// 探索日志类型枚举
enum ExplorationLogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
    case gps = "GPS"
    case speed = "SPEED"
    case distance = "DISTANCE"
    case reward = "REWARD"

    /// 日志类型对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .white
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .gps:
            return .cyan
        case .speed:
            return .yellow
        case .distance:
            return .blue
        case .reward:
            return .purple
        }
    }

    /// 日志类型对应的图标
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .gps:
            return "location"
        case .speed:
            return "speedometer"
        case .distance:
            return "figure.walk"
        case .reward:
            return "gift"
        }
    }
}

// MARK: - ExplorationLogEntry 探索日志条目

/// 探索日志条目结构
struct ExplorationLogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let type: ExplorationLogType
    let details: [String: Any]?

    init(message: String, type: ExplorationLogType, details: [String: Any]? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.type = type
        self.details = details
    }
}

// MARK: - ExplorationLogger 探索日志管理器

/// 探索功能日志管理器（单例）
@MainActor
final class ExplorationLogger: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = ExplorationLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [ExplorationLogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    /// 是否启用控制台输出
    @Published var enableConsoleOutput: Bool = true

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 500

    /// 时间格式化器（用于显示）
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// 时间格式化器（用于导出）
    private let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        // 私有初始化，确保单例
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    ///   - details: 额外详情（可选）
    func log(_ message: String, type: ExplorationLogType = .info, details: [String: Any]? = nil) {
        let entry = ExplorationLogEntry(message: message, type: type, details: details)

        // 添加到数组
        logs.append(entry)

        // 限制日志数量，移除最旧的日志
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }

        // 更新格式化文本
        updateLogText()

        // 控制台输出
        if enableConsoleOutput {
            let timestamp = displayDateFormatter.string(from: entry.timestamp)
            print("[\(timestamp)] [探索] [\(entry.type.rawValue)] \(entry.message)")
            if let details = details {
                print("  详情: \(details)")
            }
        }
    }

    /// 记录 GPS 位置更新
    func logGPS(latitude: Double, longitude: Double, accuracy: Double, speed: Double?) {
        var details: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy
        ]
        if let speed = speed {
            details["speed"] = speed
        }

        log(
            String(format: "位置更新: (%.6f, %.6f) 精度: %.1fm", latitude, longitude, accuracy),
            type: .gps,
            details: details
        )
    }

    /// 记录速度检测
    func logSpeed(_ speedKmh: Double, isOverSpeed: Bool, countdown: Int? = nil) {
        var message = String(format: "当前速度: %.1f km/h", speedKmh)
        if isOverSpeed {
            if let countdown = countdown {
                message += " [超速警告! 剩余\(countdown)秒]"
            } else {
                message += " [超速!]"
            }
        }

        log(
            message,
            type: .speed,
            details: [
                "speed_kmh": speedKmh,
                "is_over_speed": isOverSpeed,
                "countdown": countdown ?? -1
            ]
        )
    }

    /// 记录距离累计
    func logDistance(segmentDistance: Double, totalDistance: Double) {
        log(
            String(format: "距离累计: +%.1fm, 总计: %.1fm", segmentDistance, totalDistance),
            type: .distance,
            details: [
                "segment_distance": segmentDistance,
                "total_distance": totalDistance
            ]
        )
    }

    /// 记录奖励生成
    func logReward(tier: RewardTier, itemCount: Int, items: [ObtainedItem]) {
        let itemNames = items.map { $0.itemId }.joined(separator: ", ")
        log(
            "生成奖励: \(tier.displayName), \(itemCount)件物品 [\(itemNames)]",
            type: .reward,
            details: [
                "tier": tier.rawValue,
                "item_count": itemCount,
                "items": items.map { ["id": $0.itemId, "qty": $0.quantity] }
            ]
        )
    }

    /// 记录探索状态变化
    func logStateChange(from oldState: String, to newState: String) {
        log(
            "状态变化: \(oldState) → \(newState)",
            type: .info,
            details: [
                "old_state": oldState,
                "new_state": newState
            ]
        )
    }

    /// 记录探索开始
    func logExplorationStart() {
        log("🚀 探索开始", type: .success)
    }

    /// 记录探索结束
    func logExplorationEnd(distance: Double, duration: Int, status: String) {
        log(
            String(format: "🏁 探索结束: %.1fm, %d秒, 状态: %@", distance, duration, status),
            type: .success,
            details: [
                "distance": distance,
                "duration": duration,
                "status": status
            ]
        )
    }

    /// 记录错误
    func logError(_ message: String, error: Error? = nil) {
        var details: [String: Any] = [:]
        if let error = error {
            details["error"] = error.localizedDescription
        }

        log("❌ \(message)", type: .error, details: details.isEmpty ? nil : details)
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
        log("日志已清空", type: .info)
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        var output = ""

        // 添加头信息
        output += "=== 探索功能调试日志 ===\n"
        output += "导出时间: \(exportDateFormatter.string(from: Date()))\n"
        output += "日志条数: \(logs.count)\n"
        output += String(repeating: "-", count: 50) + "\n\n"

        // 添加日志内容
        for entry in logs {
            let timestamp = exportDateFormatter.string(from: entry.timestamp)
            output += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
            if let details = entry.details {
                output += "  详情: \(details)\n"
            }
        }

        return output
    }

    /// 获取最近 N 条日志
    func getRecentLogs(count: Int = 50) -> [ExplorationLogEntry] {
        return Array(logs.suffix(count))
    }

    /// 获取指定类型的日志
    func getLogs(ofType type: ExplorationLogType) -> [ExplorationLogEntry] {
        return logs.filter { $0.type == type }
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""

        for entry in logs {
            let timestamp = displayDateFormatter.string(from: entry.timestamp)
            text += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        logText = text
    }
}
