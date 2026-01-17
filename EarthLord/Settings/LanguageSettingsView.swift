//
//  LanguageSettingsView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/31.
//

import SwiftUI

struct LanguageSettingsView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 语言选项列表
                VStack(spacing: 0) {
                    // 跟随系统
                    languageOption(
                        language: .system,
                        icon: "iphone",
                        title: "跟随系统",
                        subtitle: "使用设备语言"
                    )

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.leading, 60)

                    // 简体中文
                    languageOption(
                        language: .chinese,
                        icon: "character.textbox",
                        title: "简体中文",
                        subtitle: nil
                    )

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.leading, 60)

                    // English
                    languageOption(
                        language: .english,
                        icon: "character.textbox",
                        title: "English",
                        subtitle: nil
                    )
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 提示文字
                Text("语言切换后立即生效")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationTitle("语言设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 语言选项视图

    @ViewBuilder
    private func languageOption(
        language: AppLanguage,
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                languageManager.changeLanguage(to: language)
            }
        } label: {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(languageManager.currentLanguage == language ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(width: 28)

                // 标题和副标题
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 选中标记
                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
