//
//  MainTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 全局定位管理器 - 供所有 Tab 共享
    @StateObject private var locationManager = LocationManager()

    var body: some View {
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

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(3)
        }
        .tint(ApocalypseTheme.primary)
        .environmentObject(locationManager)  // 注入全局定位管理器
    }
}

#Preview {
    MainTabView()
}
