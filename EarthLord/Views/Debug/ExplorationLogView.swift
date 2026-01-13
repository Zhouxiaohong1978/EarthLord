//
//  ExplorationLogView.swift
//  EarthLord
//
//  探索功能日志查看器 - 用于在App内查看调试日志
//

import SwiftUI

/// 探索日志查看视图
struct ExplorationLogView: View {

    // MARK: - Properties

    @ObservedObject private var logger = ExplorationLogger.shared

    /// 是否自动滚动到底部
    @State private var autoScroll: Bool = true

    /// 筛选的日志类型（nil 表示全部）
    @State private var filterType: ExplorationLogType?

    /// 搜索文本
    @State private var searchText: String = ""

    // MARK: - Computed Properties

    /// 筛选后的日志
    private var filteredLogs: [ExplorationLogEntry] {
        var logs = logger.logs

        // 按类型筛选
        if let filterType = filterType {
            logs = logs.filter { $0.type == filterType }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return logs
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选器栏
                filterBar

                // 日志列表
                logList

                // 底部工具栏
                bottomToolbar
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("探索日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { logger.clear() }) {
                            Label("清空日志", systemImage: "trash")
                        }

                        Button(action: shareLog) {
                            Label("分享日志", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    // MARK: - 筛选器栏

    private var filterBar: some View {
        VStack(spacing: 8) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("搜索日志...", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            // 类型筛选按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 全部
                    filterButton(type: nil, label: "全部", icon: "list.bullet")

                    // 各类型
                    filterButton(type: .info, label: "信息", icon: "info.circle")
                    filterButton(type: .success, label: "成功", icon: "checkmark.circle")
                    filterButton(type: .warning, label: "警告", icon: "exclamationmark.triangle")
                    filterButton(type: .error, label: "错误", icon: "xmark.circle")
                    filterButton(type: .gps, label: "GPS", icon: "location")
                    filterButton(type: .speed, label: "速度", icon: "speedometer")
                    filterButton(type: .distance, label: "距离", icon: "figure.walk")
                    filterButton(type: .reward, label: "奖励", icon: "gift")
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }

    /// 筛选按钮
    private func filterButton(type: ExplorationLogType?, label: String, icon: String) -> some View {
        Button(action: { filterType = type }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filterType == type ? ApocalypseTheme.primary : Color.white.opacity(0.1))
            .foregroundColor(filterType == type ? .white : ApocalypseTheme.textSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - 日志列表

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredLogs) { entry in
                        logEntryRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: logger.logs.count) { _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 单条日志行
    private func logEntryRow(_ entry: ExplorationLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 类型图标
            Image(systemName: entry.type.icon)
                .font(.caption)
                .foregroundColor(entry.type.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                // 时间戳
                Text(formatTime(entry.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 消息内容
                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(entry.type.color)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }

    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View {
        HStack {
            // 日志数量
            Text("\(filteredLogs.count) 条日志")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 自动滚动开关
            Toggle(isOn: $autoScroll) {
                Text("自动滚动")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.primary))
            .labelsHidden()

            Text("自动滚动")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - 分享日志

    private func shareLog() {
        let logText = logger.export()

        // 创建临时文件
        let fileName = "exploration_log_\(Date().timeIntervalSince1970).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try logText.write(to: tempURL, atomically: true, encoding: .utf8)

            // 显示分享面板
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("导出日志失败: \(error)")
        }
    }
}

// MARK: - 预览

#Preview {
    ExplorationLogView()
}
