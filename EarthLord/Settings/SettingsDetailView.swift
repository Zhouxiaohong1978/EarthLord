//
//  SettingsDetailView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/1/17.
//

import SwiftUI

struct SettingsDetailView: View {
    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 显示商城
    @State private var showStore = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            List {
                // 商城入口
                Section {
                    Button(action: { showStore = true }) {
                        HStack {
                            Image(systemName: "bag.fill")
                                .foregroundColor(ApocalypseTheme.primary)
                                .frame(width: 30)
                            Text("物资商城")
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                }

                // 语言设置
                Section {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(ApocalypseTheme.info)
                                .frame(width: 30)
                            Text("语言")
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            Text(languageManager.currentLanguage.displayName)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                }

                // 账号设置
                Section {
                    settingItem(icon: "person.fill", title: "账号信息", color: ApocalypseTheme.primary)
                    settingItem(icon: "lock.fill", title: "隐私设置", color: ApocalypseTheme.warning)
                } header: {
                    Text("账号")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 支持与隐私
                Section {
                    Link(destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/support.html")!) {
                        Text("技术支持")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)

                    Link(destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/privacy.html")!) {
                        Text("隐私政策")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                } header: {
                    Text("支持与隐私")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showStore) {
            StoreView()
        }
    }

    // MARK: - 设置项

    private func settingItem(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .listRowBackground(ApocalypseTheme.cardBackground)
    }
}

#Preview {
    NavigationStack {
        SettingsDetailView()
    }
}
