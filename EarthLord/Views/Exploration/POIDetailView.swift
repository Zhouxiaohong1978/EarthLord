//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示兴趣点的详细信息和操作按钮
//

import SwiftUI

// MARK: - 危险等级配置

/// 危险等级显示配置
struct DangerLevelConfig {
    let text: String
    let color: Color

    static func from(level: Int) -> DangerLevelConfig {
        switch level {
        case 1:
            return DangerLevelConfig(text: "安全", color: ApocalypseTheme.success)
        case 2:
            return DangerLevelConfig(text: "低危", color: ApocalypseTheme.info)
        case 3:
            return DangerLevelConfig(text: "中危", color: ApocalypseTheme.warning)
        case 4, 5:
            return DangerLevelConfig(text: "高危", color: ApocalypseTheme.danger)
        default:
            return DangerLevelConfig(text: "未知", color: ApocalypseTheme.textMuted)
        }
    }
}

// MARK: - 主视图

struct POIDetailView: View {
    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 环境变量 - 返回上一页
    @Environment(\.dismiss) private var dismiss

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 是否正在搜寻
    @State private var isExploring = false

    // MARK: - 计算属性

    /// POI 是否可以被搜寻
    private var canExplore: Bool {
        poi.status != .looted && poi.status != .undiscovered
    }

    /// 距离（假数据）
    private let distance: Int = 350

    /// 数据来源（假数据）
    private let dataSource: String = "地图数据"

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 描述区域
                    descriptionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.sampleExplorationResult)
                .presentationDetents([.large])
        }
        .overlay(alignment: .topLeading) {
            // 返回按钮
            backButton
        }
    }

    // MARK: - 返回按钮

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.4))
                )
        }
        .padding(.leading, 16)
        .padding(.top, 50)
    }

    // MARK: - 顶部大图区域

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [
                    poi.type.color,
                    poi.type.color.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            // 图标
            VStack {
                Spacer()

                Image(systemName: poi.type.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }
            .frame(height: 280)

            // 底部遮罩和文字
            VStack(alignment: .leading, spacing: 6) {
                Text(poi.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Image(systemName: poi.type.icon)
                        .font(.system(size: 14))

                    Text(poi.type.rawValue)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 0) {
            // 距离
            InfoRowView(
                icon: "location.fill",
                iconColor: ApocalypseTheme.primary,
                title: "距离",
                value: "\(distance) 米",
                valueColor: ApocalypseTheme.textPrimary
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            InfoRowView(
                icon: "shippingbox.fill",
                iconColor: ApocalypseTheme.warning,
                title: "物资状态",
                value: resourceStatusText,
                valueColor: resourceStatusColor
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            let dangerConfig = DangerLevelConfig.from(level: poi.dangerLevel)
            InfoRowView(
                icon: "exclamationmark.circle.fill",
                iconColor: dangerConfig.color,
                title: "危险等级",
                value: dangerConfig.text,
                valueColor: dangerConfig.color
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 数据来源
            InfoRowView(
                icon: "doc.text.fill",
                iconColor: ApocalypseTheme.textSecondary,
                title: "来源",
                value: dataSource,
                valueColor: ApocalypseTheme.textPrimary
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 物资状态文字
    private var resourceStatusText: String {
        switch poi.status {
        case .hasResources:
            return "有物资"
        case .looted:
            return "已清空"
        case .discovered:
            return "待搜索"
        case .undiscovered:
            return "未探索"
        case .dangerous:
            return "危险区"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        switch poi.status {
        case .hasResources:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .undiscovered:
            return ApocalypseTheme.textSecondary
        case .dangerous:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - 描述区域

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地点描述")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineSpacing(4)

            // 预估资源
            if !poi.estimatedResources.isEmpty {
                HStack(spacing: 8) {
                    Text("可能存在:")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    ForEach(poi.estimatedResources, id: \.self) { resource in
                        Text(resource)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(ApocalypseTheme.primary.opacity(0.15))
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 操作按钮区域

    private var actionSection: some View {
        VStack(spacing: 14) {
            // 主按钮：搜寻此POI
            Button {
                performExploration()
            } label: {
                HStack(spacing: 10) {
                    if isExploring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                    }

                    Text(isExploring ? "搜寻中..." : "搜寻此POI")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if canExplore {
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.gray.opacity(0.5)
                        }
                    }
                )
                .cornerRadius(14)
            }
            .disabled(!canExplore || isExploring)

            // 已清空提示
            if poi.status == .looted {
                Text("此地点已被搜空，暂时无法搜寻")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 小按钮区域
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryButton(
                    icon: "eye.fill",
                    title: "标记已发现"
                ) {
                    print("标记已发现: \(poi.name)")
                }

                // 标记无物资
                SecondaryButton(
                    icon: "xmark.circle.fill",
                    title: "标记无物资"
                ) {
                    print("标记无物资: \(poi.name)")
                }
            }
        }
    }

    /// 执行搜寻
    private func performExploration() {
        isExploring = true

        // 模拟搜寻过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isExploring = false
            showExplorationResult = true
        }
    }
}

// MARK: - 信息行组件

struct InfoRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // 标题
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 数值
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 次要按钮组件

struct SecondaryButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview("有物资") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.poiList[0])
    }
}

#Preview("已清空") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.poiList[1])
    }
}

#Preview("高危地点") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.poiList[4])
    }
}
