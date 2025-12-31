//
//  GoogleAuthService.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/31.
//

import Foundation
import GoogleSignIn
import Supabase

/// Google 登录服务
/// 负责处理 Google OAuth 登录流程
@MainActor
final class GoogleAuthService {

    // MARK: - 单例
    static let shared = GoogleAuthService()

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Google Client ID (从配置中读取)
    private var clientID: String {
        GoogleConfig.clientID
    }

    // MARK: - 初始化

    private init() {
        print("🔵 GoogleAuthService 初始化")
    }

    // MARK: - Google 登录方法

    /// 使用 Google 账号登录
    /// - Returns: Supabase Session
    /// - Throws: 登录过程中的错误
    func signInWithGoogle() async throws -> Session {
        print("🔵 开始 Google 登录流程")

        // 第一步：获取当前窗口的 rootViewController
        guard let windowScene = getWindowScene(),
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Google 登录失败：无法获取 rootViewController")
            throw GoogleAuthError.noRootViewController
        }

        print("✅ 成功获取 rootViewController")

        // 第二步：配置 Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Google Sign-In 配置完成，Client ID: \(clientID)")

        // 第三步：执行 Google 登录
        print("🔵 开始 Google 登录授权...")
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )

        guard let idToken = result.user.idToken?.tokenString else {
            print("❌ Google 登录失败：无法获取 ID Token")
            throw GoogleAuthError.noIdToken
        }

        let email = result.user.profile?.email ?? "未知邮箱"
        print("✅ Google 登录成功")
        print("   用户邮箱: \(email)")
        print("   ID Token: \(idToken.prefix(20))...")

        // 第四步：使用 ID Token 登录 Supabase
        print("🔵 开始 Supabase 登录...")
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )

        print("✅ Supabase 登录成功")
        print("   用户 ID: \(session.user.id)")
        print("   用户邮箱: \(session.user.email ?? "未知")")

        return session
    }

    /// 处理 Google 登录的 URL 回调
    /// - Parameter url: 回调 URL
    /// - Returns: 是否成功处理
    func handleURL(_ url: URL) -> Bool {
        let handled = GIDSignIn.sharedInstance.handle(url)
        if handled {
            print("✅ Google URL 回调处理成功: \(url)")
        } else {
            print("⚠️ Google URL 回调未处理: \(url)")
        }
        return handled
    }

    // MARK: - 辅助方法

    /// 获取当前窗口场景
    private func getWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            as? UIWindowScene
    }
}

// MARK: - 错误定义

/// Google 登录错误
enum GoogleAuthError: LocalizedError {
    case noRootViewController
    case noIdToken
    case supabaseError(String)

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "无法获取根视图控制器"
        case .noIdToken:
            return "无法获取 Google ID Token"
        case .supabaseError(let message):
            return "Supabase 登录失败: \(message)"
        }
    }
}
