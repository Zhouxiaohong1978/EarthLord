//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/23.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !splashFinished {
                    // 启动页
                    SplashView(isFinished: $splashFinished)
                        .transition(.opacity)
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
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
        }
    }
}
