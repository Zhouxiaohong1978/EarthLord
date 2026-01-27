//
//  AuthView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/29.
//

import SwiftUI

/// 认证页面 - 登录/注册
struct AuthView: View {

    // MARK: - 属性

    /// 认证管理器（从环境获取或使用共享实例）
    @ObservedObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab: Int = 0

    /// 登录表单
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    /// 注册表单
    @State private var registerEmail: String = ""
    @State private var registerCode: String = ""
    @State private var registerPassword: String = ""
    @State private var registerConfirmPassword: String = ""

    /// 重发验证码倒计时
    @State private var resendCountdown: Int = 0
    @State private var resendTimer: Timer?

    /// 忘记密码弹窗
    @State private var showForgotPassword: Bool = false
    @State private var forgotEmail: String = ""
    @State private var forgotCode: String = ""
    @State private var forgotPassword: String = ""
    @State private var forgotConfirmPassword: String = ""
    @State private var forgotStep: Int = 1
    @State private var forgotResendCountdown: Int = 0

    /// Toast 提示
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 和标题
                    headerView

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerView

                    // 第三方登录
                    socialLoginView

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                hideKeyboard()
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.errorMessage) { newValue in
            if let message = newValue {
                showToastMessage(message)
            }
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.12, green: 0.10, blue: 0.16),
                Color(red: 0.08, green: 0.08, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部视图

    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

            // 标题
            Text("末日之主")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("征服世界，从这里开始")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                }
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == 0 {
                                Rectangle()
                                    .fill(ApocalypseTheme.primary)
                                    .frame(height: 3)
                            }
                        }
                    )
            }

            // 注册 Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            } label: {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == 1 {
                                Rectangle()
                                    .fill(ApocalypseTheme.primary)
                                    .frame(height: 3)
                            }
                        }
                    )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入框
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入框
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 登录按钮
            PrimaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码链接
            Button {
                forgotEmail = loginEmail
                forgotStep = 1
                showForgotPassword = true
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 注册视图（三步流程）

    private var registerView: some View {
        VStack(spacing: 20) {
            // 根据状态显示不同步骤
            if authManager.needsPasswordSetup && authManager.otpVerified {
                // 第三步：设置密码
                registerStep3View
            } else if authManager.otpSent && !authManager.otpVerified {
                // 第二步：验证码验证
                registerStep2View
            } else {
                // 第一步：输入邮箱
                registerStep1View
            }

            // 步骤指示器
            stepIndicator
        }
    }

    /// 注册第一步：输入邮箱
    private var registerStep1View: some View {
        VStack(spacing: 20) {
            Text("第一步：输入邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "请输入邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startResendCountdown()
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    /// 注册第二步：验证码验证
    private var registerStep2View: some View {
        VStack(spacing: 20) {
            Text("第二步：输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(String(format: NSLocalizedString("验证码已发送至 %@", comment: ""), registerEmail))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入框
            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerCode,
                keyboardType: .numberPad
            )

            HStack(spacing: 12) {
                // 验证按钮
                PrimaryButton(title: "验证") {
                    Task {
                        await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                    }
                }
                .disabled(registerCode.count != 6)

                // 重发按钮
                Button {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        if authManager.otpSent {
                            startResendCountdown()
                        }
                    }
                } label: {
                    Text(resendCountdown > 0 ? "\(resendCountdown)s" : "重发")
                        .font(.subheadline)
                        .foregroundColor(resendCountdown > 0 ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                        .frame(width: 60)
                }
                .disabled(resendCountdown > 0)
            }
        }
    }

    /// 注册第三步：设置密码
    private var registerStep3View: some View {
        VStack(spacing: 20) {
            Text("第三步：设置密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证成功！请设置您的登录密码")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.success)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "完成注册") {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    /// 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(currentRegisterStep >= step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 10)
    }

    /// 当前注册步骤
    private var currentRegisterStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3
        } else if authManager.otpSent {
            return 2
        } else {
            return 1
        }
    }

    // MARK: - 分隔线

    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 第三方登录

    private var socialLoginView: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮
            Button {
                // 先收起键盘
                hideKeyboard()
                print("🍎 Apple 登录按钮被点击")
                Task {
                    // 等待键盘完全收起（300ms）
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    print("🍎 开始执行 Apple 登录")
                    await authManager.signInWithApple()
                    print("🍎 Apple 登录完成")
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("通过 Apple 登录")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录按钮
            Button {
                // 先收起键盘，避免 Siri 建议拦截
                hideKeyboard()
                print("🔵 Google 登录按钮被点击")
                Task {
                    // 等待键盘和 Siri 建议完全收起（500ms）
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    print("🔵 开始执行 Google 登录")
                    await authManager.signInWithGoogle()
                    print("🔵 Google 登录完成")
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("通过 Google 登录")
                        .fontWeight(.medium)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 收起键盘
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - 忘记密码弹窗

    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 步骤指示
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { step in
                                Circle()
                                    .fill(forgotStep >= step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        switch forgotStep {
                        case 1:
                            forgotStep1View
                        case 2:
                            forgotStep2View
                        case 3:
                            forgotStep3View
                        default:
                            EmptyView()
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetForgotPasswordState()
                        showForgotPassword = false
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// 找回密码第一步
    private var forgotStep1View: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "请输入邮箱",
                text: $forgotEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: forgotEmail)
                    if authManager.otpSent {
                        forgotStep = 2
                        startForgotResendCountdown()
                    }
                }
            }
            .disabled(forgotEmail.isEmpty || !isValidEmail(forgotEmail))
        }
    }

    /// 找回密码第二步
    private var forgotStep2View: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(String(format: NSLocalizedString("验证码已发送至 %@", comment: ""), forgotEmail))
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $forgotCode,
                keyboardType: .numberPad
            )

            HStack(spacing: 12) {
                PrimaryButton(title: "验证") {
                    Task {
                        await authManager.verifyResetOTP(email: forgotEmail, code: forgotCode)
                        if authManager.otpVerified {
                            forgotStep = 3
                        }
                    }
                }
                .disabled(forgotCode.count != 6)

                Button {
                    Task {
                        await authManager.sendResetOTP(email: forgotEmail)
                        startForgotResendCountdown()
                    }
                } label: {
                    Text(forgotResendCountdown > 0 ? "\(forgotResendCountdown)s" : "重发")
                        .font(.subheadline)
                        .foregroundColor(forgotResendCountdown > 0 ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                        .frame(width: 60)
                }
                .disabled(forgotResendCountdown > 0)
            }
        }
    }

    /// 找回密码第三步
    private var forgotStep3View: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $forgotPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $forgotConfirmPassword
            )

            if !forgotConfirmPassword.isEmpty && forgotPassword != forgotConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "重置密码") {
                Task {
                    await authManager.resetPassword(newPassword: forgotPassword)
                    if authManager.isAuthenticated {
                        resetForgotPasswordState()
                        showForgotPassword = false
                    }
                }
            }
            .disabled(
                forgotPassword.count < 6 ||
                forgotPassword != forgotConfirmPassword
            )
        }
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 提示

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - 辅助方法

    /// 显示 Toast 消息
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
            authManager.clearError()
        }
    }

    /// 开始重发倒计时
    private func startResendCountdown() {
        resendCountdown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    /// 开始找回密码重发倒计时
    private func startForgotResendCountdown() {
        forgotResendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if forgotResendCountdown > 0 {
                forgotResendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 重置找回密码状态
    private func resetForgotPasswordState() {
        forgotEmail = ""
        forgotCode = ""
        forgotPassword = ""
        forgotConfirmPassword = ""
        forgotStep = 1
        forgotResendCountdown = 0
        authManager.resetFlowState()
    }
}

// MARK: - 自定义组件

/// 自定义输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.none)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .textContentType(.none)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .textContentType(.none)
            }

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 主按钮
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isEnabled ? ApocalypseTheme.primary : ApocalypseTheme.textMuted
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - 预览

#Preview {
    AuthView()
}
