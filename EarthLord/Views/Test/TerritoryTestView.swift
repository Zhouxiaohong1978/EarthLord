//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面 - 显示实时日志
//

import SwiftUI
import CoreLocation

struct TerritoryTestView: View {

    // MARK: - Environment & Observed Objects

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - State

    /// 是否正在创建测试领地
    @State private var isCreatingTestTerritory = false

    /// 是否正在删除测试领地
    @State private var isDeletingTestTerritories = false

    /// 测试领地距离（米）
    @State private var testDistance: Double = 200

    /// 测试领地大小（米）
    @State private var testSize: Double = 50

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 测试领地控制区域
            testTerritorySection
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志滚动区域
            logScrollArea

            Divider()

            // 底部按钮栏
            bottomButtons
                .padding()
                .background(ApocalypseTheme.cardBackground)
        }
        .navigationTitle("圈地测试")
        .background(ApocalypseTheme.background)
    }

    // MARK: - 状态指示器

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "● 追踪中" : "○ 未追踪")
                .font(.headline)
                .foregroundColor(locationManager.isTracking ? .green : ApocalypseTheme.textSecondary)

            Spacer()

            // 路径点数
            if locationManager.pathCoordinates.count > 0 {
                Text("\(locationManager.pathCoordinates.count) 个点")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 日志滚动区域

    /// 日志滚动区域
    private var logScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        Text("暂无日志\n\n请前往地图页面开始圈地追踪")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        // 显示日志
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                                .id(entry.id)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: logger.logText) { _ in
                // 日志更新时自动滚动到底部
                if let lastLog = logger.logs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 日志条目视图
    /// - Parameter entry: 日志条目
    /// - Returns: 格式化的日志视图
    private func logEntryView(_ entry: LogEntry) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: entry.timestamp)

        return HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text("[\(timestamp)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 类型标签
            Text("[\(entry.type.displayName)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.type.color)
                .frame(width: 70, alignment: .leading)

            // 消息内容
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
    }

    // MARK: - 测试领地控制区域

    /// 测试领地控制区域
    private var testTerritorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("测试第三方领地")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 当前位置显示
            if let location = locationManager.userLocation {
                Text("当前位置: \(String(format: "%.4f, %.4f", location.latitude, location.longitude))")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Text("等待定位...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }

            // 距离滑块
            VStack(alignment: .leading, spacing: 4) {
                Text("距离: \(Int(testDistance)) 米")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Slider(value: $testDistance, in: 50...500, step: 10)
                    .tint(ApocalypseTheme.primary)
            }

            // 大小滑块
            VStack(alignment: .leading, spacing: 4) {
                Text("领地大小: \(Int(testSize)) 米")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Slider(value: $testSize, in: 20...100, step: 5)
                    .tint(ApocalypseTheme.primary)
            }

            // 按钮行
            HStack(spacing: 12) {
                // 创建测试领地按钮
                Button(action: {
                    Task {
                        await createTestTerritory()
                    }
                }) {
                    HStack {
                        if isCreatingTestTerritory {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.square.fill")
                        }
                        Text(isCreatingTestTerritory ? "创建中..." : "创建测试领地")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
                .disabled(locationManager.userLocation == nil || isCreatingTestTerritory)
                .opacity(locationManager.userLocation == nil ? 0.5 : 1)

                // 删除所有测试领地按钮
                Button(action: {
                    Task {
                        await deleteAllTestTerritories()
                    }
                }) {
                    HStack {
                        if isDeletingTestTerritories {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(isDeletingTestTerritories ? "删除中..." : "清除测试领地")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(8)
                }
                .disabled(isDeletingTestTerritories)
            }

        }
    }

    /// 创建测试领地
    private func createTestTerritory() async {
        guard let location = locationManager.userLocation else {
            TerritoryLogger.shared.log("无法创建测试领地：未获取到位置", type: .error)
            return
        }

        isCreatingTestTerritory = true
        TerritoryLogger.shared.log("开始创建测试领地，距离: \(Int(testDistance))米", type: .info)

        do {
            let coords = try await TerritoryManager.shared.createTestTerritoryNearby(
                center: location,
                distanceMeters: testDistance,
                sizeMeters: testSize
            )

            await MainActor.run {
                isCreatingTestTerritory = false
                TerritoryLogger.shared.log("测试领地创建成功！共 \(coords.count) 个顶点", type: .success)
            }
        } catch {
            await MainActor.run {
                isCreatingTestTerritory = false
                TerritoryLogger.shared.log("创建失败: \(error.localizedDescription)", type: .error)
            }
        }
    }

    /// 删除所有测试领地
    private func deleteAllTestTerritories() async {
        isDeletingTestTerritories = true
        TerritoryLogger.shared.log("开始删除所有测试领地...", type: .info)

        do {
            try await TerritoryManager.shared.deleteAllTestTerritories()

            await MainActor.run {
                isDeletingTestTerritories = false
            }
        } catch {
            await MainActor.run {
                isDeletingTestTerritories = false
                TerritoryLogger.shared.log("删除失败: \(error.localizedDescription)", type: .error)
            }
        }
    }

    // MARK: - 底部按钮

    /// 底部按钮栏
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                withAnimation {
                    logger.clear()
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.danger.opacity(0.2))
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1)

            // 导出日志按钮
            ShareLink(
                item: logger.export(),
                preview: SharePreview(
                    "圈地测试日志",
                    image: Image(systemName: "doc.text")
                )
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager.shared)
    }
}
