//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能测试日志管理器 - 在 App 内显示调试日志
//

import Foundation
import SwiftUI
import Combine

// MARK: - LogType 日志类型

/// 日志类型枚举
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

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
        }
    }
}

// MARK: - LogEntry 日志条目

/// 日志条目结构
struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let type: LogType

    init(message: String, type: LogType) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.type = type
    }
}

// MARK: - TerritoryLogger 日志管理器

/// 圈地功能测试日志管理器（单例）
@MainActor
final class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 时间格式化器（用于显示）
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（用于导出）
    private let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// 日志文件路径（持久化磁盘，崩溃后日志仍保留）
    private let logFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("territory_crash_log.txt")
    }()

    // MARK: - Initialization

    private init() {
        loadFromDisk()
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(message: message, type: type)

        // 添加到数组
        logs.append(entry)

        // 限制日志数量，移除最旧的日志
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }

        // 更新格式化文本
        updateLogText()

        // 追加写入磁盘（崩溃后仍可读）
        appendToDisk(entry: entry)
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
        try? FileManager.default.removeItem(at: logFileURL)
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        var output = ""

        // 添加头信息
        output += "=== 圈地功能测试日志 ===\n"
        output += "导出时间: \(exportDateFormatter.string(from: Date()))\n"
        output += "日志条数: \(logs.count)\n"
        output += "\n"

        // 添加日志内容
        for entry in logs {
            let timestamp = exportDateFormatter.string(from: entry.timestamp)
            output += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return output
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

    /// 追加一条日志到磁盘文件
    private func appendToDisk(entry: LogEntry) {
        let timestamp = exportDateFormatter.string(from: entry.timestamp)
        let line = "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            guard let fileHandle = try? FileHandle(forWritingTo: logFileURL) else { return }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    /// 启动时从磁盘加载上次的日志
    private func loadFromDisk() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8),
              !content.isEmpty else { return }
        // 直接恢复 logText，让用户打开日志页面时能看到崩溃前的记录
        logText = "=== 上次运行日志（崩溃后恢复）===\n" + content + "\n=== 本次运行 ===\n"
    }
}
