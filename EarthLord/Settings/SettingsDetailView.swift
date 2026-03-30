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
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 显示新手教程
    @State private var showOnboarding = false
    /// 退出登录确认弹窗
    @State private var showLogoutAlert = false
    /// 删除账户确认弹窗
    @State private var showDeleteAccountSheet = false
    /// 删除账户确认输入文本
    @State private var deleteConfirmationText = ""
    /// 是否正在删除账户
    @State private var isDeletingAccount = false
    /// 删除账户错误信息
    @State private var deleteErrorMessage: String?
    /// 显示删除错误提示
    @State private var showDeleteError = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            List {
                // 语言设置
                Section {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(ApocalypseTheme.info)
                                .frame(width: 30)
                            Text("settings.language")
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            Text(languageManager.currentLanguage.displayName)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                }

                // 新手教程
                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(ApocalypseTheme.info)
                                .frame(width: 30)
                            Text("settings.tutorial")
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                }

                // 账号设置
                Section {
                    // 退出登录
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(ApocalypseTheme.warning)
                                .frame(width: 30)
                            Text("settings.logout")
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)

                    // 删除账户
                    Button {
                        showDeleteAccountSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(ApocalypseTheme.danger)
                                .frame(width: 30)
                            Text("settings.delete.account")
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                } header: {
                    Text("settings.section.account")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 支持与隐私
                Section {
                    Link(destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/support.html")!) {
                        Text("settings.support")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)

                    Link(destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/privacy.html")!) {
                        Text("settings.privacy")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)

                    Link(destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/terms.html")!) {
                        Text("settings.terms")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
                } header: {
                    Text("settings.section.support")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        .alert(Text("settings.logout.confirm.title"), isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("settings.logout.confirm.button", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("settings.logout.confirm.message")
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            deleteAccountConfirmationView
        }
        .alert(Text("settings.delete.fail.title"), isPresented: $showDeleteError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? String(localized: "error.unknown"))
        }
    }

    // MARK: - 删除账户确认视图

    private var deleteAccountConfirmationView: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 40)

                    Text("settings.delete.permanent.title")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.delete.warning.header")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        warningItem(text: String(localized: "settings.delete.warning.1"))
                        warningItem(text: String(localized: "settings.delete.warning.2"))
                        warningItem(text: String(localized: "settings.delete.warning.3"))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.danger.opacity(0.1))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("settings.delete.confirm.hint")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Spacer()
                            if !deleteConfirmationText.isEmpty {
                                let trimmed = deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
                                let confirmWord = deleteConfirmWord
                                Image(systemName: trimmed == confirmWord ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(trimmed == confirmWord ? ApocalypseTheme.success : ApocalypseTheme.danger)
                            }
                        }
                        TextField(deleteConfirmWord, text: $deleteConfirmationText)
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            Task { await performDeleteAccount() }
                        } label: {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("settings.delete.confirm.button")
                                    .font(.body).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(isDeleteButtonEnabled ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                        .cornerRadius(12)
                        .disabled(!isDeleteButtonEnabled || isDeletingAccount)

                        Button {
                            dismissDeleteSheet()
                        } label: {
                            Text("取消")  // LocalizedStringKey → "Cancel"
                                .font(.body).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .disabled(isDeletingAccount)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle(Text("settings.delete.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismissDeleteSheet() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .interactiveDismissDisabled(isDeletingAccount)
        }
    }

    private func warningItem(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(ApocalypseTheme.danger)
            Text(text)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    private var isDeleteConfirmWordMatched: Bool {
        let trimmed = deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "删除" || trimmed.lowercased() == "delete"
    }

    private var deleteConfirmWord: String { "Delete / 删除" }

    private var isDeleteButtonEnabled: Bool { isDeleteConfirmWordMatched }

    private func performDeleteAccount() async {
        guard isDeleteConfirmWordMatched else { return }
        isDeletingAccount = true
        do {
            try await authManager.deleteAccount()
            dismissDeleteSheet()
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
            isDeletingAccount = false
        }
    }

    private func dismissDeleteSheet() {
        showDeleteAccountSheet = false
        deleteConfirmationText = ""
        isDeletingAccount = false
    }
}

#Preview {
    NavigationStack {
        SettingsDetailView()
    }
}
