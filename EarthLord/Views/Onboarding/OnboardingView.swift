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
            description: "末日降临，文明崩溃。\n你是少数幸存者之一。\n\n圈地、探索、建造、通讯——\n四大核心玩法带你从零建立末日领地。",
            color: .orange
        ),
        OnboardingPage(
            icon: "🗺️",
            title: "出门圈地",
            description: "在地图上沿边界行走，\n回到起点即可圈定属于你的领地。\n\n领地越大，可建造的设施越多，\n每日产出的资源也越丰厚。",
            color: .green
        ),
        OnboardingPage(
            icon: "🎒",
            title: "出门探索，搜刮物资",
            description: "点击「开始探索」，带着手机出门步行。\n\n走满 200m 即可领取距离奖励，\n走满 500m 后，靠近附近的医院、超市等地点，\n可触发搜刮，额外获得物品。\n\n走得越远，物品越多、品质越高。",
            color: .blue
        ),
        OnboardingPage(
            icon: "🏗️",
            title: "建造庇护所",
            description: "这是你在末日中最重要的事。\n\n用背包里的物资在领地内建造各类设施：\n· 庇护所 — 每日自动产出基础资源\n· 医疗站 — 提升队伍恢复能力\n· 通讯塔 — 扩大通讯范围\n\n建筑等级越高，收益越强大。",
            color: .orange
        ),
        OnboardingPage(
            icon: "📦",
            title: "资源交易",
            description: "背包装不下？或者缺少某种材料？\n\n前往「资源」页面，\n把多余的物资挂单出售，\n或购买其他幸存者的物资。\n\n合理交易，让每一份资源都发挥最大价值。",
            color: .purple
        ),
        OnboardingPage(
            icon: "📡",
            title: "与幸存者通讯",
            description: "你并不孤单。\n\n设置你的专属呼号，\n通过通讯频道联系附近的幸存者，\n组建联盟，共享资源，共御威胁。\n\n通讯塔建得越高，覆盖范围越广。",
            color: .cyan
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
        VStack(spacing: 32) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(page.color.opacity(0.08))
                    .frame(width: 180, height: 180)
                Text(page.icon)
                    .font(.system(size: 70))
            }

            // 文字
            VStack(spacing: 16) {
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
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    OnboardingView(onFinish: {})
}
