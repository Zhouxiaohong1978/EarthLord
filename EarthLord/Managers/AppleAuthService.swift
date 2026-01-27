//
//  AppleAuthService.swift
//  EarthLord
//
//  Created by Claude on 2026/1/24.
//

import Foundation
import AuthenticationServices
import Supabase

/// Apple 登录服务
/// 负责处理 Sign in with Apple 登录流程
@MainActor
final class AppleAuthService: NSObject {

    // MARK: - 单例
    static let shared = AppleAuthService()

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 登录完成回调
    private var signInContinuation: CheckedContinuation<Session, Error>?

    // MARK: - 初始化

    private override init() {
        super.init()
        print("🍎 AppleAuthService 初始化")
    }

    // MARK: - Apple 登录方法

    /// 使用 Apple 账号登录
    /// - Returns: Supabase Session
    /// - Throws: 登录过程中的错误
    func signInWithApple() async throws -> Session {
        print("🍎 开始 Apple 登录流程")

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            // 创建 Apple ID 请求
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            // 创建授权控制器
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self

            print("🍎 开始 Apple 登录授权...")
            authorizationController.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    /// 授权成功
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            print("🍎 Apple 授权成功，处理凭证...")

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Apple 登录失败：无法获取 Apple ID 凭证")
                signInContinuation?.resume(throwing: AppleAuthError.invalidCredential)
                signInContinuation = nil
                return
            }

            // 获取 ID Token
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                print("❌ Apple 登录失败：无法获取 ID Token")
                signInContinuation?.resume(throwing: AppleAuthError.noIdToken)
                signInContinuation = nil
                return
            }

            // 获取用户信息（首次登录时才有）
            let email = appleIDCredential.email ?? "未提供"
            let fullName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            print("✅ Apple 授权完成")
            print("   用户 ID: \(appleIDCredential.user)")
            print("   邮箱: \(email)")
            print("   姓名: \(fullName.isEmpty ? "未提供" : fullName)")
            print("   ID Token: \(identityToken.prefix(20))...")

            // 使用 ID Token 登录 Supabase
            do {
                print("🍎 开始 Supabase 登录...")
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken
                    )
                )

                print("✅ Supabase 登录成功")
                print("   用户 ID: \(session.user.id)")
                print("   用户邮箱: \(session.user.email ?? "未知")")

                signInContinuation?.resume(returning: session)
            } catch {
                print("❌ Supabase 登录失败: \(error)")
                signInContinuation?.resume(throwing: AppleAuthError.supabaseError(error.localizedDescription))
            }

            signInContinuation = nil
        }
    }

    /// 授权失败
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            print("❌ Apple 授权失败: \(error)")

            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    print("   用户取消了登录")
                    signInContinuation?.resume(throwing: AppleAuthError.userCancelled)
                case .failed:
                    print("   授权请求失败")
                    signInContinuation?.resume(throwing: AppleAuthError.authorizationFailed)
                case .invalidResponse:
                    print("   授权响应无效")
                    signInContinuation?.resume(throwing: AppleAuthError.invalidResponse)
                case .notHandled:
                    print("   授权请求未处理")
                    signInContinuation?.resume(throwing: AppleAuthError.notHandled)
                case .notInteractive:
                    print("   授权请求非交互式")
                    signInContinuation?.resume(throwing: AppleAuthError.notInteractive)
                default:
                    // 处理 .unknown, .matchedExcludedCredential, .deviceNotConfiguredForPasskeyCreation,
                    // .credentialImport, .credentialExport, .preferSignInWithApple 等其他错误
                    print("   其他错误: \(authError.code)")
                    signInContinuation?.resume(throwing: AppleAuthError.unknown)
                }
            } else {
                signInContinuation?.resume(throwing: error)
            }

            signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {

    /// 提供展示授权界面的窗口
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 使用 MainActor.assumeIsolated 安全访问 UI 属性
        // 这个方法总是在主线程调用
        return MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive } as? UIWindowScene
            let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
            return window ?? ASPresentationAnchor()
        }
    }
}

// MARK: - 错误定义

/// Apple 登录错误
enum AppleAuthError: LocalizedError {
    case invalidCredential
    case noIdToken
    case userCancelled
    case authorizationFailed
    case invalidResponse
    case notHandled
    case notInteractive
    case deviceNotConfigured
    case unknown
    case supabaseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "无法获取 Apple ID 凭证"
        case .noIdToken:
            return "无法获取 Apple ID Token"
        case .userCancelled:
            return "用户取消了登录"
        case .authorizationFailed:
            return "Apple 授权请求失败"
        case .invalidResponse:
            return "Apple 授权响应无效"
        case .notHandled:
            return "Apple 授权请求未处理"
        case .notInteractive:
            return "Apple 授权请求需要交互"
        case .deviceNotConfigured:
            return "设备未配置 Apple 登录"
        case .unknown:
            return "Apple 登录发生未知错误"
        case .supabaseError(let message):
            return "Supabase 登录失败: \(message)"
        }
    }
}
