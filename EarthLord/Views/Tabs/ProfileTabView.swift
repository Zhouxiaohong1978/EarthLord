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

    /// 显示退出确认弹窗
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 用户头像和信息
                        userInfoSection

                        // 菜单列表
                        menuSection

                        // 退出登录按钮
                        logoutButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 180)
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }

    // MARK: - 用户信息区域

    private var userInfoSection: some View {
        VStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 100, height: 100)

                // 显示用户名首字符
                Text(avatarText)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)

            // 用户名
            Text(displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 邮箱
            Text(authManager.currentUser?.email ?? "未设置邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 用户ID
            if let userId = authManager.currentUser?.id.uuidString {
                Text("ID: \(String(userId.prefix(8)))...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
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
            menuItem(icon: "gearshape.fill", title: "设置", subtitle: "账号与隐私设置", color: ApocalypseTheme.primary)
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
        .cornerRadius(16)
    }

    private var menuDivider: some View {
        Divider()
            .background(ApocalypseTheme.textMuted.opacity(0.3))
            .padding(.leading, 56)
    }

    private func menuItem(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body)
                Text("退出登录")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .padding(.top, 10)
    }
}

#Preview {
    ProfileTabView()
}
