//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 邮箱管理器
    @StateObject private var mailboxManager = MailboxManager.shared

    /// 显示退出确认弹窗
    @State private var showLogoutAlert = false

    /// 显示删除账户确认弹窗
    @State private var showDeleteAccountSheet = false

    /// 删除账户确认输入文本
    @State private var deleteConfirmationText = ""

    /// 是否正在删除账户
    @State private var isDeletingAccount = false

    /// 删除账户错误信息
    @State private var deleteErrorMessage: String?

    /// 显示删除错误提示
    @State private var showDeleteError = false

    /// 显示商城
    @State private var showStore = false

    /// 显示邮箱
    @State private var showMailbox = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // 用户头像和信息
                        userInfoSection

                        // 菜单列表
                        menuSection

                        // 退出登录按钮
                        logoutButton

                        // 删除账户按钮
                        deleteAccountButton
                            .padding(.bottom, 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 邮箱按钮（带红点提示）
                        Button(action: { showMailbox = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(ApocalypseTheme.primary)

                                // 未读红点
                                if mailboxManager.unreadCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 18, height: 18)

                                        Text("\(mailboxManager.unreadCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }

                        // 商城按钮
                        Button(action: { showStore = true }) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 20))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showStore) {
                StoreView()
            }
            .sheet(isPresented: $showMailbox) {
                MailboxView()
            }
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
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
            .onAppear {
                // 加载未读邮件数量
                Task {
                    await mailboxManager.loadUnreadCount()
                }
            }
        }
    }

    // MARK: - 用户信息区域

    private var userInfoSection: some View {
        VStack(spacing: 10) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 80, height: 80)

                // 显示用户名首字符
                Text(avatarText)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 12)

            // 用户名
            Text(displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 邮箱
            Text(authManager.currentUser?.email ?? "未设置邮箱")
                .font(.footnote)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 用户ID
            if let userId = authManager.currentUser?.id.uuidString {
                Text(String(format: NSLocalizedString("ID: %@...", comment: ""), String(userId.prefix(8))))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 头像显示文字（用户名首字符）
    private var avatarText: String {
        let name = displayName
        if let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    /// 显示名称
    private var displayName: String {
        // 优先使用 user_metadata 中的 username
        if let username = authManager.currentUser?.userMetadata["username"]?.stringValue,
           !username.isEmpty {
            return username
        }
        // 其次使用 email 的前缀
        if let email = authManager.currentUser?.email {
            return String(email.split(separator: "@").first ?? "")
        }
        return "用户"
    }

    // MARK: - 菜单区域

    private var menuSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsDetailView()
            } label: {
                menuItemContent(icon: "gearshape.fill", title: "设置", subtitle: "账号与隐私设置", color: ApocalypseTheme.primary)
            }
            menuDivider
            menuItem(icon: "bell.fill", title: "通知", subtitle: "消息提醒设置", color: ApocalypseTheme.warning)
            menuDivider
            menuItem(icon: "shield.fill", title: "安全", subtitle: "密码与登录安全", color: ApocalypseTheme.danger)
            menuDivider
            menuItem(icon: "questionmark.circle.fill", title: "帮助", subtitle: "常见问题与反馈", color: ApocalypseTheme.info)
            menuDivider
            menuItem(icon: "info.circle.fill", title: "关于", subtitle: "版本信息", color: ApocalypseTheme.success)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var menuDivider: some View {
        Divider()
            .background(ApocalypseTheme.textMuted.opacity(0.3))
            .padding(.leading, 56)
    }

    private func menuItemContent(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func menuItem(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, color: Color) -> some View {
        menuItemContent(icon: icon, title: title, subtitle: subtitle, color: color)
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.callout)
                Text("退出登录")
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.primary)
            .cornerRadius(10)
        }
        .padding(.top, 6)
    }

    // MARK: - 删除账户按钮

    private var deleteAccountButton: some View {
        Button {
            print("🔴 用户点击删除账户按钮")
            showDeleteAccountSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.callout)
                Text("删除账户")
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.danger)
            .cornerRadius(10)
        }
        .padding(.top, 4)
    }

    // MARK: - 删除账户确认视图

    private var deleteAccountConfirmationView: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 40)

                    // 警告标题
                    Text("永久删除账户")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 警告信息
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

                    // 确认输入框
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("请输入「删除」以确认")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Spacer()

                            // 显示匹配状态
                            if !deleteConfirmationText.isEmpty {
                                let trimmed = deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed == "删除" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ApocalypseTheme.success)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(ApocalypseTheme.danger)
                                }
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
                            .onChange(of: deleteConfirmationText) { newValue in
                                print("📝 输入变化: [\(newValue)]")
                                print("   字符数: \(newValue.count)")
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                print("   去空格后: [\(trimmed)] (字符数: \(trimmed.count))")

                                // 打印每个字符的 Unicode 值用于调试
                                if !trimmed.isEmpty {
                                    print("   Unicode 值:", trimmed.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))
                                }

                                print("   匹配结果: \(trimmed == "删除")")
                                print("   按钮状态: \(isDeleteButtonEnabled ? "启用" : "禁用")")
                            }
                    }

                    Spacer()

                    // 按钮组
                    VStack(spacing: 12) {
                        // 确认删除按钮
                        Button {
                            Task {
                                await performDeleteAccount()
                            }
                        } label: {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("确认删除账户")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(isDeleteButtonEnabled ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                        .cornerRadius(12)
                        .disabled(!isDeleteButtonEnabled || isDeletingAccount)

                        // 取消按钮
                        Button {
                            print("🔵 用户取消删除账户")
                            dismissDeleteSheet()
                        } label: {
                            Text("取消")
                                .font(.body)
                                .fontWeight(.medium)
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
                    Button {
                        print("🔵 用户点击关闭按钮")
                        dismissDeleteSheet()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .interactiveDismissDisabled(isDeletingAccount)
        }
    }

    // MARK: - 辅助视图

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

    // MARK: - 辅助方法

    /// 删除按钮是否可用
    private var isDeleteButtonEnabled: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "删除"
    }

    /// 执行删除账户
    private func performDeleteAccount() async {
        let trimmed = deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔴 开始执行删除账户操作")
        print("📝 确认文本：[\(deleteConfirmationText)]")
        print("📝 去空格后：[\(trimmed)]")

        guard trimmed == "删除" else {
            print("❌ 确认文本不匹配")
            return
        }

        isDeletingAccount = true

        do {
            print("📞 调用 AuthManager.deleteAccount()")
            try await authManager.deleteAccount()
            print("✅ 账户删除成功，关闭弹窗")
            dismissDeleteSheet()
        } catch {
            print("❌ 删除账户失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
            isDeletingAccount = false
        }
    }

    /// 关闭删除账户弹窗
    private func dismissDeleteSheet() {
        showDeleteAccountSheet = false
        deleteConfirmationText = ""
        isDeletingAccount = false
    }
}

#Preview {
    ProfileTabView()
}
