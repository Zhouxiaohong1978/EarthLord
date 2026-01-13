//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/23.
//

import SwiftUI
import os.log

@main
struct EarthLordApp: App {
    /// 系统日志器
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "EarthLord", category: "App")

    init() {
        NSLog("🌍 ========== EarthLord 应用启动 ==========")
        print("🌍 ========== EarthLord 应用启动 ==========")
        logger.notice("🌍 EarthLord 应用启动")

        // 初始化探索日志器和管理器（在主线程上执行）
        Task { @MainActor in
            // 初始化探索日志器
            _ = ExplorationLogger.shared
            NSLog("✅ [App] ExplorationLogger 已初始化")
            print("✅ [App] ExplorationLogger 已初始化")

            // 初始化探索管理器
            _ = ExplorationManager.shared
            NSLog("✅ [App] ExplorationManager 已初始化")
            print("✅ [App] ExplorationManager 已初始化")

            // 初始化背包管理器
            _ = InventoryManager.shared
            NSLog("✅ [App] InventoryManager 已初始化")
            print("✅ [App] InventoryManager 已初始化")

            // 初始化统计管理器
            _ = ExplorationStatsManager.shared
            NSLog("✅ [App] ExplorationStatsManager 已初始化")
            print("✅ [App] ExplorationStatsManager 已初始化")

            NSLog("🚀 [App] 所有管理器初始化完成")
            print("🚀 [App] 所有管理器初始化完成")
        }
    }
    /// 认证管理器 - 使用 lazy 初始化避免启动时的问题
    @StateObject private var authManager = AuthManager.shared

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

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
            .id(languageManager.currentLocale) // 语言切换时强制重新创建视图
            .environmentObject(languageManager)
            .environment(\.locale, .init(identifier: languageManager.currentLocale))
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
