//
//  MoreTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    // 开发者工具部分
                    Section {
                        NavigationLink {
                            TestMenuView()
                        } label: {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver")
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 30)
                                Text("开发测试")
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text("开发者工具")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    MoreTabView()
}
