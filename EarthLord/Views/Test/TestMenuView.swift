//
//  TestMenuView.swift
//  EarthLord
//
//  测试模块入口菜单
//

import SwiftUI

struct TestMenuView: View {

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    Text("Supabase 连接测试")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 12) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    Text("圈地功能测试")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
