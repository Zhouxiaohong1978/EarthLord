//
//  RootView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

/// 根视图：控制启动页 → 认证页 → 引导页 → 主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 是否已看过引导页（按 userId 存，换账号自动重置）
    @State private var hasSeenOnboarding = false

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    private func onboardingKey(for userId: String) -> String {
        "hasSeenOnboarding_\(userId)"
    }

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 未登录：显示认证页面
                AuthView()
                    .transition(.opacity)
            } else if !hasSeenOnboarding {
                // 首次登录：显示引导页
                OnboardingView {
                    if let userId = authManager.currentUser?.id.uuidString {
                        UserDefaults.standard.set(true, forKey: onboardingKey(for: userId))
                    }
                    hasSeenOnboarding = true
                }
                .transition(.opacity)
            } else {
                // 已登录且看过引导：显示主界面
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .onChange(of: authManager.currentUser) { user in
            if let userId = user?.id.uuidString {
                hasSeenOnboarding = UserDefaults.standard.bool(forKey: onboardingKey(for: userId))
            } else {
                hasSeenOnboarding = false
            }
        }
    }
}

#Preview {
    RootView()
}
