//
//  ExplorationTabView.swift
//  EarthLord
//
//  探索模块入口 Tab
//  提供 POI 列表和背包管理的入口
//

import SwiftUI

struct ExplorationTabView: View {
    var body: some View {
        NavigationStack {
            POIListView()
                .toolbar {
                    // 背包按钮
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: BackpackView()) {
                            Image(systemName: "bag.fill")
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                }
                .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    ExplorationTabView()
}
