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

    /// 是否为管理员
    @Published var isAdmin: Bool = false

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    /// 注册验证码是否已发送（等待用户输入 OTP）
    @Published var registerOTPSent: Bool = false

    /// 待验证的注册邮箱（内部使用）
    private(set) var pendingRegisterEmail: String = ""

    /// 关联账号的用户 ID 列表（包括当前用户自己）
    @Published var linkedUserIds: Set<String> = []

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化

    private init() {
        // 延迟启动认证状态监听，避免初始化时的潜在问题
        Task { @MainActor in
            // 等待一小段时间确保应用完全启动
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            self.startAuthStateListener()
            // 检查当前会话
            await self.checkSession()
        }
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
                    // 获取关联账号列表 + 刷新账号专属状态
                    Task {
                        await self.fetchLinkedUserIds()
                        await self.fetchAdminStatus()
                        await SubscriptionManager.shared.refreshSubscriptionStatus()
                        _ = try? await InventoryManager.shared.refreshInventory()
                    }
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
                    // 登录成功后启动位置上报
                    LocationReporter.shared.startReporting()
                    print("📍 位置上报已启动")
                    // 刷新当前账号的状态，防止跨账号数据污染
                    Task {
                        await self.fetchLinkedUserIds()
                        await self.fetchAdminStatus()
                        await SubscriptionManager.shared.refreshSubscriptionStatus()
                        _ = try? await InventoryManager.shared.refreshInventory()
                    }
                }
                print("✅ 用户登录: \(session.user.email ?? "unknown")")
            }

        case .signedOut:
            // 用户登出 - 先标记离线再停止上报
            Task {
                await LocationReporter.shared.markOffline()
                LocationReporter.shared.stopReporting()
                print("📍 位置上报已停止")
            }
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            linkedUserIds = []
            isAdmin = false
            // 重置各 Manager 状态，防止跨账号数据污染
            InventoryManager.shared.resetForLogout()
            SubscriptionManager.shared.resetForLogout()
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
    /// 注册新用户（邮箱+密码+用户名）
    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil

        print("📝 开始注册: \(email), 用户名: \(username)")

        // 先检查用户名是否已被占用
        do {
            let available: Bool = try await supabase
                .rpc("check_username_available", params: ["p_username": username])
                .execute()
                .value
            if !available {
                errorMessage = "用户名「\(username)」已被使用，请换一个"
                isLoading = false
                return
            }
        } catch {
            print("⚠️ 用户名检查失败，继续注册: \(error)")
        }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: username.isEmpty ? nil : ["username": .string(username)]
            )

            // 检查邮箱是否已被注册（Supabase 对已存在的邮箱返回 identities 为空）
            if response.user.identities?.isEmpty ?? true {
                errorMessage = "该邮箱已被注册，请直接登录"
                print("⚠️ 邮箱已被注册: \(email)")
                isLoading = false
                return
            }

            // 注册成功
            if let session = response.session {
                currentUser = session.user
                isAuthenticated = true
                print("✅ 注册成功，已自动登录")
            } else {
                // Supabase 配置了邮箱验证，需要用户输入 OTP
                pendingRegisterEmail = email
                registerOTPSent = true
                print("✅ 注册请求成功，等待用户输入邮箱验证码: \(email)")
            }
        } catch {
            errorMessage = "注册失败: \(error.localizedDescription)"
            print("❌ 注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 注册 OTP 验证

    /// 验证注册验证码
    /// - Parameter code: 用户输入的 6 位验证码
    func verifyRegisterOTP(code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.verifyOTP(
                email: pendingRegisterEmail,
                token: code,
                type: .signup
            )
            currentUser = session.user
            registerOTPSent = false
            pendingRegisterEmail = ""
            isAuthenticated = true
            print("✅ 注册验证码验证成功")
        } catch {
            errorMessage = "验证码错误或已过期，请重试"
            print("❌ 注册验证码验证失败: \(error)")
        }

        isLoading = false
    }

    /// 重新发送注册验证码
    func resendRegisterOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.resend(email: pendingRegisterEmail, type: .signup)
            print("📧 注册验证码已重新发送到: \(pendingRegisterEmail)")
        } catch {
            errorMessage = "重发验证码失败: \(error.localizedDescription)"
            print("❌ 重发注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置注册 OTP 状态
    func resetRegisterOTPState() {
        registerOTPSent = false
        pendingRegisterEmail = ""
        errorMessage = nil
    }

    // MARK: - 登录方法

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        print("🔐 开始登录: \(email)")

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功: \(session.user.email ?? "unknown")")
        } catch let error as NSError {
            // 详细错误信息
            print("❌ 登录失败详情:")
            print("   错误域: \(error.domain)")
            print("   错误码: \(error.code)")
            print("   错误描述: \(error.localizedDescription)")
            print("   详细信息: \(error)")

            // 根据错误类型提供友好的提示
            if error.localizedDescription.contains("Invalid login credentials") ||
               error.localizedDescription.contains("invalid") {
                errorMessage = "邮箱或密码错误，请检查后重试"
            } else if error.localizedDescription.contains("Email not confirmed") {
                errorMessage = "邮箱未验证，请先验证邮箱"
            } else if error.localizedDescription.contains("network") ||
                      error.localizedDescription.contains("connection") {
                errorMessage = "网络连接失败，请检查网络"
            } else {
                errorMessage = "登录失败: \(error.localizedDescription)"
            }
        } catch {
            print("❌ 登录失败: \(error)")
            errorMessage = "登录失败: \(error.localizedDescription)"
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

    // MARK: - 第三方登录

    /// 使用 Apple 账号登录
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        print("🍎 开始 Apple 登录流程")

        do {
            // 调用 AppleAuthService 执行登录
            let session = try await AppleAuthService.shared.signInWithApple()

            // 登录成功，更新状态
            currentUser = session.user
            isAuthenticated = true

            print("✅ Apple 登录完成")
            print("   用户邮箱: \(session.user.email ?? "未知")")
        } catch let error as AppleAuthError {
            // Apple 登录特定错误
            print("❌ Apple 登录失败: \(error.localizedDescription)")
            // 用户取消登录时不显示错误提示
            if case .userCancelled = error {
                print("   用户取消了 Apple 登录")
            } else {
                errorMessage = "Apple 登录失败: \(error.localizedDescription)"
            }
        } catch {
            // 其他错误
            print("❌ Apple 登录失败: \(error)")
            errorMessage = "Apple 登录失败，请重试"
        }

        isLoading = false
    }

    /// 使用 Google 账号登录
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        print("🔵 开始 Google 登录流程")

        do {
            // 调用 GoogleAuthService 执行登录
            let session = try await GoogleAuthService.shared.signInWithGoogle()

            // 登录成功，更新状态
            currentUser = session.user
            isAuthenticated = true

            print("✅ Google 登录完成")
            print("   用户邮箱: \(session.user.email ?? "未知")")
        } catch let error as GoogleAuthError {
            // Google 登录特定错误
            print("❌ Google 登录失败: \(error.localizedDescription)")
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
        } catch {
            // 其他错误
            print("❌ Google 登录失败: \(error)")
            errorMessage = "Google 登录失败，请重试"
        }

        isLoading = false
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

    /// 删除账户
    /// 调用 Supabase 边缘函数删除当前用户账户
    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil

        print("🗑️ 开始删除账户...")

        do {
            // 调用边缘函数删除账户
            _ = try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    body: Data() // 空请求体
                )
            )

            print("✅ 账户删除成功")

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

        } catch {
            print("❌ 删除账户失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            throw error
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
        registerOTPSent = false
        pendingRegisterEmail = ""
        errorMessage = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 获取关联账号 ID 列表
    /// 调用数据库函数获取当前用户及其关联账号的所有 ID
    func fetchAdminStatus() async {
        guard let userId = currentUser?.id else { return }
        do {
            struct AdminRow: Decodable { let is_admin: Bool }
            let rows: [AdminRow] = try await supabase
                .from("profiles")
                .select("is_admin")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            await MainActor.run {
                self.isAdmin = rows.first?.is_admin ?? false
            }
        } catch {
            await MainActor.run { self.isAdmin = false }
        }
    }

    func fetchLinkedUserIds() async {
        guard let userId = currentUser?.id else {
            linkedUserIds = []
            return
        }

        do {
            let response: [String] = try await supabase
                .rpc("get_all_linked_user_ids", params: ["user_id": userId.uuidString])
                .execute()
                .value

            await MainActor.run {
                self.linkedUserIds = Set(response.map { $0.lowercased() })
                print("🔗 关联账号: \(self.linkedUserIds.count) 个")
            }
        } catch {
            // 如果获取失败，至少包含当前用户
            await MainActor.run {
                self.linkedUserIds = [userId.uuidString.lowercased()]
                print("⚠️ 获取关联账号失败，仅使用当前用户: \(error.localizedDescription)")
            }
        }
    }

    /// 检查指定用户 ID 是否属于当前用户（包括关联账号）
    func isLinkedUser(_ userId: String) -> Bool {
        return linkedUserIds.contains(userId.lowercased())
    }
}
