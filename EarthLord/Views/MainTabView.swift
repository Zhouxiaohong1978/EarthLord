//
//  MainTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 全局定位管理器 - 供所有 Tab 共享（使用单例）
    @StateObject private var locationManager = LocationManager.shared

    /// 订阅管理器 - 用于显示过期横幅
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // 设置 TabBar 外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ApocalypseTheme.cardBackground)

        // 未选中状态：使用较亮的灰白色，确保可见
        let normalColor = UIColor(white: 0.7, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]

        // 选中状态：使用主题橙色
        let selectedColor = UIColor(ApocalypseTheme.primary)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                MapTabView()
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text("地图")
                    }
                    .tag(0)

                TerritoryTabView()
                    .tabItem {
                        Image(systemName: "flag.fill")
                        Text("领地")
                    }
                    .tag(1)

                ExplorationTabView()
                    .tabItem {
                        Image(systemName: "shippingbox.fill")
                        Text("资源")
                    }
                    .tag(2)

                CommunicationTabView()
                    .tabItem {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("通讯")
                    }
                    .tag(3)

                ProfileTabView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("个人")
                    }
                    .tag(4)
            }
            .tint(ApocalypseTheme.primary)
            .environmentObject(locationManager)  // 注入全局定位管理器
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMailbox)) { _ in
                // 切换到资源 Tab（index 2）
                withAnimation {
                    selectedTab = 2
                }
            }

            // 订阅过期横幅（仅在横幅可见时响应触摸，否则透传到 TabView）
            VStack {
                SubscriptionExpirationBanner()
                Spacer()
            }
            .allowsHitTesting(subscriptionManager.isExpired || subscriptionManager.isExpiringSoon)
        }
        .onAppear {
            // 延迟检查过期订阅（等10秒确保 ProfileTabView 的串行操作全部完成）
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await subscriptionManager.handleExpiredSubscriptions()
            }
        }
    }
}

#Preview {
    MainTabView()
}
