//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/23.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器 - 使用 lazy 初始化避免启动时的问题
    @StateObject private var authManager = AuthManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    /// 应用是否已准备好
    @State private var isReady = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !splashFinished || !isReady {
                    // 启动页
                    SplashView(isFinished: $splashFinished)
                        .transition(.opacity)
                        .onAppear {
                            // 确保应用初始化完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isReady = true
                            }
                        }
                } else if !authManager.isAuthenticated || authManager.needsPasswordSetup {
                    // 未登录或需要设置密码：显示认证页面
                    AuthView()
                        .environmentObject(authManager)
                        .transition(.opacity)
                } else {
                    // 已登录且完成所有流程：显示主界面
                    MainTabView()
                        .environmentObject(authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: splashFinished)
            .animation(.easeInOut(duration: 0.3), value: isReady)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
            .onOpenURL { url in
                // 处理 Google 登录回调 URL
                print("📱 收到 URL 回调: \(url)")
                let handled = GoogleAuthService.shared.handleURL(url)
                if handled {
                    print("✅ URL 已被 Google 登录处理")
                } else {
                    print("⚠️ URL 未被处理: \(url)")
                }
            }
        }
    }
}
