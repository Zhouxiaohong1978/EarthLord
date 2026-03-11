//
//  ClaimingRulesView.swift
//  EarthLord
//
//  圈地规则说明界面 - 用户点击"开始圈地"时弹出
//

import SwiftUI

struct ClaimingRulesView: View {

    var onCancel: () -> Void
    var onStart: () -> Void

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: 顶部导航栏
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        Button(action: onStart) {
                            Text("开始圈地")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(ApocalypseTheme.info)
                        Text("圈地规则")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // MARK: 内容区域
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        // 基础要求
                        RuleSection(
                            icon: "checkmark.circle.fill",
                            title: "基础要求",
                            accentColor: .green,
                            items: [
                                "至少需要走 10 个 GPS 点",
                                "总距离不少于 50 米",
                                "起点和终点距离需要在 30 米内闭合",
                                "领地面积不少于 100 平方米"
                            ]
                        )

                        // 禁止行为
                        RuleSection(
                            icon: "xmark.octagon.fill",
                            title: "禁止行为",
                            accentColor: .red,
                            items: [
                                "轨迹不能自己交叉（禁止\"8字形\"）",
                                "不能与他人领地边界重叠（5米容差）",
                                "不能圈占包含他人领地的区域",
                                "移动速度不能超过 15km/h（防止开车）"
                            ]
                        )

                        // 建议
                        RuleSection(
                            icon: "lightbulb.fill",
                            title: "建议",
                            accentColor: Color(red: 1.0, green: 0.75, blue: 0.0),
                            items: [
                                "选择空旷、GPS 信号良好的区域",
                                "步行圈地，保持稳定速度",
                                "注意避开他人领地（地图上显示为多边形）",
                                "尽量走直线或简单形状，避免复杂路径"
                            ]
                        )

                        // 三层验证保护
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 3)
                                .cornerRadius(1.5)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkered")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                    Text("三层验证保护")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }

                                Text("您的领地将经过客户端、服务器和数据库三层验证，确保公平游戏。")
                                    .font(.system(size: 13))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            Spacer()
                        }
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }

                Spacer().frame(height: 20)
            }
        }
    }
}

// MARK: - 规则区块组件

private struct RuleSection: View {
    let icon: String
    let title: LocalizedStringKey
    let accentColor: Color
    let items: [LocalizedStringKey]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧色条
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 10) {
                // 标题
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                        .font(.system(size: 14))
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                // 条目列表
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)

                            Text(items[index])
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer()
        }
        .background(accentColor.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    ClaimingRulesView(onCancel: {}, onStart: {})
}
