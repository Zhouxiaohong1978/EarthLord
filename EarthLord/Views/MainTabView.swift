//
//  MainTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

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
                        Text(LocalizedStringKey("地图"))
                    }
                    .tag(0)

                TerritoryTabView()
                    .tabItem {
                        Image(systemName: "flag.fill")
                        Text(LocalizedStringKey("领地"))
                    }
                    .tag(1)

                ExplorationTabView()
                    .tabItem {
                        Image(systemName: "shippingbox.fill")
                        Text(LocalizedStringKey("资源"))
                    }
                    .tag(2)

                CommunicationTabView()
                    .tabItem {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(LocalizedStringKey("通讯"))
                    }
                    .tag(3)

                ProfileTabView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text(LocalizedStringKey("个人"))
                    }
                    .tag(4)
            }
            .tint(ApocalypseTheme.primary)
            .environmentObject(locationManager)  // 注入全局定位管理器
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMailbox)) { _ in
                withAnimation { selectedTab = 2 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToBackpack)) { _ in
                withAnimation { selectedTab = 2 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMapTab)) { _ in
                // 切换到地图 Tab（index 0）
                withAnimation {
                    selectedTab = 0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToTerritoryTab)) { _ in
                // 切换到领地 Tab（index 1）
                withAnimation {
                    selectedTab = 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToCommunicationTab)) { _ in
                // 切换到通讯 Tab（index 3）
                withAnimation {
                    selectedTab = 3
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
        .onChange(of: scenePhase) { phase in
            // App 从后台切回前台时刷新订阅状态，确保过期不延迟生效
            if phase == .active {
                Task {
                    await subscriptionManager.refreshSubscriptionStatus()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
