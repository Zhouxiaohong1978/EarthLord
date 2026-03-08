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
            description: "末日降临，文明崩溃。\n你是少数幸存者之一，\n现在是时候建立属于你的领地了。",
            color: .orange
        ),
        OnboardingPage(
            icon: "🗺️",
            title: "出门圈地",
            description: "打开地图，走到你想占领的地方。\n点击「开始标记」，沿着边界行走，\n回到起点即可完成圈地。\n面积越大，资源越多！",
            color: .green
        ),
        OnboardingPage(
            icon: "🎒",
            title: "探索收集资源",
            description: "在你的领地范围内探索，\n可以收集水、食物、金属、木材等物资。\n物资存放在背包，可用于建造或交易。",
            color: .blue
        ),
        OnboardingPage(
            icon: "📦",
            title: "建造与交易",
            description: "用收集的物资在领地内建造设施，\n提升你的生存能力。\n也可以在资源市场与其他幸存者交易，\n互通有无共渡难关。",
            color: .purple
        ),
        OnboardingPage(
            icon: "📡",
            title: "与幸存者通讯",
            description: "设置你的专属呼号，\n加入通讯频道，\n与附近的幸存者联络，\n组建联盟共同生存。",
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
