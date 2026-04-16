//
//  OnboardingView.swift
//  EarthLord
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "🌍",
            title: "欢迎来到末日之主",
            description: "末日降临，文明崩溃。\n你是少数幸存者之一。\n\n圈地、探索、建造、交易、通讯——\n五大核心玩法带你从零建立末日领地。",
            color: .orange,
            highlights: []
        ),
        OnboardingPage(
            icon: "🗺️",
            title: "出门圈地",
            description: "在地图上沿边界步行，\n回到起点即可圈定属于你的领地。\n\n领地越大，可建造的设施越多，\n每日产出的资源也越丰厚。",
            color: .green,
            highlights: [
                HighlightItem(icon: "flag.fill", color: .green, text: "圈地后可设置领地名称和税率"),
                HighlightItem(icon: "dollarsign.circle.fill", color: .yellow, text: "其他玩家在你领地搜刮物资，税收自动入邮箱")
            ]
        ),
        OnboardingPage(
            icon: "🎒",
            title: "出门探索，搜刮物资",
            description: "点击「开始探索」，带着手机出门步行。\n走满 200m 领取距离奖励，走满 500m 解锁废墟搜刮。",
            color: .blue,
            highlights: [
                HighlightItem(icon: "figure.walk", color: .blue, text: "走得越远，奖励物品越多、品质越高（最高传奇级）"),
                HighlightItem(icon: "mappin.and.ellipse", color: .cyan, text: "医院/超市/工厂附近可触发搜刮，获得 AI 生成的末日物资"),
                HighlightItem(icon: "key.fill", color: .orange, text: "持有「搜刮令」可远程搜刮，无需步行到现场"),
                HighlightItem(icon: "calendar.badge.clock", color: .gray, text: "幸存者每日最多探索 10 次，订阅后无限次")
            ]
        ),
        OnboardingPage(
            icon: "🏗️",
            title: "建造你的末日基地",
            description: "有了领地，才能建造。探索获得物资，存入仓库，在领地内建造各类设施。",
            color: .orange,
            highlights: [
                HighlightItem(icon: "flag.fill", color: .orange, text: "建造入口：点击底部「领地」→ 选择领地 → 建造"),
                HighlightItem(icon: "archivebox.fill", color: .brown, text: "物资先存仓库，建造时系统自动从背包+仓库扣除"),
                HighlightItem(icon: "arrow.up.circle.fill", color: .yellow, text: "建筑可升级强化，等级越高收益越强，但需要更多物资"),
                HighlightItem(icon: "wrench.fill", color: .gray, text: "定期维护建筑保持运行，耐久耗尽则停止产出")
            ]
        ),
        OnboardingPage(
            icon: "📦",
            title: "资源管理与交易",
            description: "背包装不下？或者缺少某种材料？\n\n前往「资源」页面统一管理你的物品：",
            color: .purple,
            highlights: [
                HighlightItem(icon: "backpack.fill", color: .purple, text: "背包 — 外出探索携带的物资"),
                HighlightItem(icon: "archivebox.fill", color: .brown, text: "领地物品 — 建造材料存放在领地仓库"),
                HighlightItem(icon: "tag.fill", color: .green, text: "交易市场 — 挂单出售或购买全球玩家物资"),
                HighlightItem(icon: "envelope.fill", color: .blue, text: "邮箱 — 领地税收、系统礼包自动投递")
            ]
        ),
        OnboardingPage(
            icon: "📡",
            title: "通讯：合作与竞争",
            description: "末日世界里，信息就是生存优势。设置专属呼号，加入频道，与全球幸存者合作或博弈。",
            color: .cyan,
            highlights: [
                HighlightItem(icon: "person.fill.badge.plus", color: .cyan, text: "通讯入口：底部「通讯」→ 加入或创建频道"),
                HighlightItem(icon: "star.fill", color: .yellow, text: "收藏常用频道，公共频道·LIVE 实时查看全球动态"),
                HighlightItem(icon: "waveform", color: .green, text: "PTT 对讲 — 按住录音，松手即发送语音至频道"),
                HighlightItem(icon: "antenna.radiowaves.left.and.right", color: .cyan, text: "设备升级：收音机 → 对讲机 → 营地电台 → 卫星通讯，覆盖范围逐级扩大"),
                HighlightItem(icon: "megaphone.fill", color: .orange, text: "末日官方广播发布重要情报，关注获取生存资讯")
            ]
        ),
        OnboardingPage(
            icon: "🏆",
            title: "排行榜与成就",
            description: "你在废土上的每一步都被记录。与全球幸存者竞技，解锁专属成就勋章。",
            color: .yellow,
            highlights: [
                HighlightItem(icon: "chart.bar.fill", color: .yellow, text: "全球排行榜：领地面积、探索废墟数量、建筑数量多维度排名"),
                HighlightItem(icon: "medal.fill", color: .orange, text: "完成挑战任务解锁成就勋章，记录你的末日传奇"),
                HighlightItem(icon: "person.fill", color: .cyan, text: "成就入口：底部「个人」→ 成就 / 排行榜")
            ]
        ),
        OnboardingPage(
            icon: "❤️",
            title: "体征监控",
            description: "末日生存不只是抢资源，保持良好的生存状态才能走得更远。",
            color: .red,
            highlights: [
                HighlightItem(icon: "heart.fill", color: .red, text: "实时监控体力、饥饿度、饮水量、健康值"),
                HighlightItem(icon: "exclamationmark.triangle.fill", color: .orange, text: "体征过低会影响探索效率，及时补充食物和水"),
                HighlightItem(icon: "cross.fill", color: .green, text: "体征入口：底部「个人」→ 体征")
            ]
        ),
        OnboardingPage(
            icon: "👑",
            title: "订阅解锁更多特权",
            description: "免费玩家可体验全部核心玩法，订阅后解锁更强加成和专属权益。",
            color: .purple,
            highlights: [
                HighlightItem(icon: "figure.walk", color: .blue, text: "探索者：探索奖励×1.5，搜刮冷却缩短，解锁更多建造权限"),
                HighlightItem(icon: "crown.fill", color: .yellow, text: "领主：探索奖励×2，头像专属王冠，全部高级功能无限使用"),
                HighlightItem(icon: "cube.fill", color: .orange, text: "物资包：一次性购买稀有建造材料，加速基地建设")
            ]
        )
    ]

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            onFinish()
                        }
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 50)

                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // 底部控制区
                VStack(spacing: 24) {
                    // 页面指示器
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.4))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }

                    // 按钮
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            onFinish()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "下一步" : "开始生存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func pageView(page: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                // 图标
                ZStack {
                    Circle()
                        .fill(page.color.opacity(0.15))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(page.color.opacity(0.08))
                        .frame(width: 168, height: 168)
                    Text(page.icon)
                        .font(.system(size: 64))
                }
                .padding(.top, 20)

                // 标题 + 描述
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(page.description)
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 28)
                }

                // 高亮要点（如有）
                if !page.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(page.highlights) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(item.color)
                                    .frame(width: 20)
                                    .padding(.top, 1)
                                Text(item.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 16)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
    let highlights: [HighlightItem]
}

struct HighlightItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: LocalizedStringKey
}

#Preview {
    OnboardingView(onFinish: {})
}
