//
//  AuthManager.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/29.
//

import Foundation
import Combine
import Supabase

/// 认证管理器
/// 负责处理用户注册、登录、找回密码等认证流程
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后的状态）
    @Published var needsPasswordSetup: Bool = false

    /// 当前用户
    @Published var currentUser: Auth.User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化

    private init() {
        // 启动认证状态监听
        startAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - 认证状态监听

    /// 启动认证状态变化监听
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }

            // 监听认证状态变化
            for await (event, session) in self.supabase.auth.authStateChanges {
                await MainActor.run {
                    self.handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件
    ///   - session: 会话信息
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("🔐 认证状态变化: \(event)")

        switch event {
        case .initialSession:
            // 初始会话加载
            if let session = session {
                currentUser = session.user
                // 检查是否需要设置密码
                if needsPasswordSetup {
                    isAuthenticated = false
                } else {
                    isAuthenticated = true
                }
                print("✅ 初始会话: \(session.user.email ?? "unknown")")
            } else {
                isAuthenticated = false
                currentUser = nil
                print("ℹ️ 无初始会话")
            }

        case .signedIn:
            // 用户登录
            if let session = session {
                currentUser = session.user
                // 如果不是通过 OTP 验证登录（需要设置密码），则直接设为已认证
                if !needsPasswordSetup {
                    isAuthenticated = true
                }
                print("✅ 用户登录: \(session.user.email ?? "unknown")")
            }

        case .signedOut:
            // 用户登出
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            print("✅ 用户已登出")

        case .tokenRefreshed:
            // Token 刷新
            if let session = session {
                currentUser = session.user
                print("🔄 Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("📝 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复
            print("🔑 密码恢复流程")

        case .mfaChallengeVerified:
            // MFA 验证
            print("🔐 MFA 验证完成")

        case .userDeleted:
            // 用户删除
            isAuthenticated = false
            currentUser = nil
            print("🗑️ 用户已删除")
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用 signInWithOTP 发送验证码，shouldCreateUser: true 表示创建新用户
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("📧 注册验证码已发送到: \(email)")
        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功后，用户已登录，但需要设置密码
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，直到设置密码完成

            print("✅ 注册验证码验证成功，等待设置密码")
        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: Auth.UserAttributes(password: password))

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true

            print("✅ 注册完成，密码已设置")
        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功: \(session.user.email ?? "unknown")")
        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 发送重置密码邮件（触发 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("📧 重置密码验证码已发送到: \(email)")
        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // ⚠️ 注意：重置密码使用 type: .recovery，不是 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功后，用户已登录，等待设置新密码
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置密码验证码验证成功，等待设置新密码")
        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: Auth.UserAttributes(password: newPassword))

            // 密码重置成功
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true

            print("✅ 密码重置成功")
        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// 使用 Apple 账号登录
    /// TODO: 实现 Apple 登录
    /// - 需要配置 Apple Developer 账号
    /// - 需要在 Supabase Dashboard 启用 Apple Provider
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 获取 Apple ID credential
        // 2. 调用 supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken))
        print("🍎 Apple 登录 - 待实现")
    }

    /// 使用 Google 账号登录
    /// TODO: 实现 Google 登录
    /// - 需要配置 Google Cloud Console
    /// - 需要在 Supabase Dashboard 启用 Google Provider
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 Google Sign-In SDK 获取 ID token
        // 2. 调用 supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken))
        print("🔵 Google 登录 - 待实现")
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 已退出登录")
        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否有密码（通过 identities 判断）
            // 如果用户通过 OTP 登录但未设置密码，需要强制设置
            if let identities = session.user.identities,
               identities.contains(where: { $0.provider == "email" }) {
                // 用户有邮箱身份，已完成注册
                isAuthenticated = true
                needsPasswordSetup = false
            } else {
                // 可能是未完成注册的用户
                isAuthenticated = false
            }

            print("✅ 会话有效: \(session.user.email ?? "unknown")")
        } catch {
            // 没有有效会话
            isAuthenticated = false
            currentUser = nil
            print("ℹ️ 无有效会话: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 重置流程状态（用于取消操作或重新开始）
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}
