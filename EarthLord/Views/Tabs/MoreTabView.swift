//
//  MoreTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    // 成就
                    NavigationLink {
                        AchievementView()
                            .navigationTitle("成就")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbarColorScheme(.dark, for: .navigationBar)
                    } label: {
                        MoreMenuRow(
                            icon: "trophy.fill",
                            iconColor: ApocalypseTheme.warning,
                            title: "成就",
                            subtitle: "查看你的末日旅程"
                        )
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                    .listRowSeparatorTint(Color.white.opacity(0.08))

                    // 语言设置（仅开发环境）
                    #if DEBUG
                    languagePickerRow
                        .listRowBackground(ApocalypseTheme.cardBackground)
                        .listRowSeparatorTint(Color.white.opacity(0.08))
                    #endif
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(LocalizedStringKey("更多"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 语言选择行

    private var languagePickerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.info.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "globe")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.info)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("语言"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.currentLanguage.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Picker("", selection: $languageManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .tint(ApocalypseTheme.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 更多菜单行组件

struct MoreMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MoreTabView()
        .environmentObject(LanguageManager.shared)
}
