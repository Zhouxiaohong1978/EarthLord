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

                // 新手教程
                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(ApocalypseTheme.info)
                                .frame(width: 30)
                            Text("新手教程")
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
                            Text("退出登录")
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
                            Text("删除账户")
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                    }
                    .listRowBackground(ApocalypseTheme.cardBackground)
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("确定要退出登录吗？")
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            deleteAccountConfirmationView
        }
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? "未知错误")
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

                    Text("永久删除账户")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("此操作将：")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        warningItem(text: "永久删除您的账户和所有数据")
                        warningItem(text: "删除您的个人信息和设置")
                        warningItem(text: "此操作不可撤销")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.danger.opacity(0.1))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("请输入「删除」以确认")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Spacer()
                            if !deleteConfirmationText.isEmpty {
                                let trimmed = deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
                                Image(systemName: trimmed == "删除" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(trimmed == "删除" ? ApocalypseTheme.success : ApocalypseTheme.danger)
                            }
                        }
                        TextField("删除", text: $deleteConfirmationText)
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
                                Text("确认删除账户")
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
                            Text("取消")
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
            .navigationTitle("删除账户")
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

    private var isDeleteButtonEnabled: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "删除"
    }

    private func performDeleteAccount() async {
        guard deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "删除" else { return }
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
