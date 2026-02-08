//
//  SubscriptionView.swift
//  EarthLord
//
//  订阅页面主界面
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {

    // MARK: - State

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    @State private var isLoading = true
    @State private var showConfirmSheet = false
    @State private var showResultView = false
    @State private var selectedProduct: Product?
    @State private var selectedTier: SubscriptionTier?
    @State private var subscriptionResult: SubscriptionResultView.ResultType?

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 当前订阅状态卡片
                    if subscriptionManager.isSubscribed {
                        currentSubscriptionCard
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    // 标题
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, subscriptionManager.isSubscribed ? 10 : 20)

                    // 周期切换（月卡/年卡）
                    periodSelector
                        .padding(.horizontal, 16)

                    // 订阅档位卡片
                    subscriptionCards
                        .padding(.horizontal, 16)

                    // 底部说明
                    footerSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                }
            }

            // 加载指示器（自身 loading 或 manager 正在加载时都显示）
            if isLoading || (subscriptionManager.isLoadingProducts && subscriptionManager.availableSubscriptions.isEmpty) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)
            }
        }
        .navigationTitle("幸存者特权")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .onAppear {
            // 如果商品已经预加载完成，直接使用缓存数据
            if !subscriptionManager.availableSubscriptions.isEmpty {
                isLoading = false
                return
            }
            // 如果预加载正在进行中，等待它完成即可（onChange 会响应）
            if subscriptionManager.isLoadingProducts {
                return
            }
            // 未预加载时延迟1秒再请求，避免NavigationLink转场期间的GCD并发崩溃
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task {
                    await loadData()
                }
            }
        }
        .onChange(of: subscriptionManager.availableSubscriptions.count) { _ in
            // 预加载完成后自动更新加载状态
            if !subscriptionManager.availableSubscriptions.isEmpty {
                isLoading = false
            }
        }
        .sheet(isPresented: $showConfirmSheet) {
            if let product = selectedProduct, let tier = selectedTier {
                SubscriptionConfirmSheet(
                    product: product,
                    tier: tier,
                    onConfirm: {
                        await confirmSubscribe()
                    },
                    onCancel: {
                        cancelSubscribe()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showResultView) {
            if let result = subscriptionResult {
                SubscriptionResultView(
                    result: result,
                    onDismiss: {
                        showResultView = false
                        subscriptionResult = nil
                    }
                )
            }
        }
    }

    // MARK: - 当前订阅状态卡片

    private var currentSubscriptionCard: some View {
        VStack(spacing: 12) {
            HStack {
                // 档位徽章
                Text(subscriptionManager.currentTier.badgeIcon)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionManager.currentTier.displayName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if let subscription = subscriptionManager.currentSubscription {
                        if subscription.isExpired {
                            Text("已过期")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                        } else {
                            Text("到期时间: \(formatDate(subscription.expiresAt))")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("剩余 \(subscription.daysRemaining) 天")
                                .font(.caption)
                                .foregroundColor(subscriptionManager.isExpiringSoon ? ApocalypseTheme.warning : ApocalypseTheme.success)
                        }
                    }
                }

                Spacer()

                // 管理按钮
                Button("管理") {
                    // TODO: 跳转到订阅管理页面
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - 标题部分

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("解锁专属特权")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("成为探索者或领主，畅享末日生存之旅")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 周期选择器

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(SubscriptionPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(period.rawValue)
                            .font(.system(size: 15, weight: selectedPeriod == period ? .semibold : .medium))
                            .foregroundColor(selectedPeriod == period ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                        if period == .yearly {
                            Text("更划算")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.primary)
                                .opacity(selectedPeriod == period ? 1 : 0.6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedPeriod == period ?
                            ApocalypseTheme.cardBackground :
                            Color.clear
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 订阅卡片列表

    private var subscriptionCards: some View {
        VStack(spacing: 16) {
            // 免费档位（仅展示，不可购买）
            freeTierCard

            // 探索者档位
            if let explorerProduct = getProduct(for: selectedPeriod, tier: .explorer) {
                SubscriptionCard(
                    product: explorerProduct,
                    tier: .explorer,
                    isCurrentTier: subscriptionManager.currentTier == .explorer,
                    isRecommended: false,
                    onSubscribe: {
                        await handleSubscribe(explorerProduct)
                    }
                )
            }

            // 领主档位（推荐）
            if let lordProduct = getProduct(for: selectedPeriod, tier: .lord) {
                SubscriptionCard(
                    product: lordProduct,
                    tier: .lord,
                    isCurrentTier: subscriptionManager.currentTier == .lord,
                    isRecommended: true,
                    onSubscribe: {
                        await handleSubscribe(lordProduct)
                    }
                )
            }
        }
    }

    // MARK: - 免费档位卡片

    private var freeTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("🆓 幸存者")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if subscriptionManager.currentTier == .free {
                    Text("当前档位")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                        )
                }
            }

            // 价格
            Text("免费")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 权益列表
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "backpack.fill", text: "背包容量 100")
                benefitRow(icon: "map.fill", text: "探索范围 1km")
                benefitRow(icon: "building.2.fill", text: "建造速度 1倍")
                benefitRow(icon: "arrow.triangle.2.circlepath", text: "交易次数 10次/天")
                benefitRow(icon: "house.fill", text: "庇护所收益 10次/天")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 底部说明

    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("订阅说明")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("• 订阅将自动续费，可随时取消")
                Text("• 取消后订阅将在当前周期结束时失效")
                Text("• 价格可能因地区而异")
                Text("• 订阅特权立即生效")
            }
            .font(.caption2)
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helper Views

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Methods

    private func loadData() async {
        isLoading = true

        print("📦 [SubscriptionView] 开始加载订阅商品...")

        // 加载订阅商品
        await subscriptionManager.loadSubscriptions()

        print("📦 [SubscriptionView] 商品加载完成，数量: \(subscriptionManager.availableSubscriptions.count)")

        // 商品加载完成后立即关闭loading，让用户能看到界面
        isLoading = false

        print("📦 [SubscriptionView] 开始刷新订阅状态...")

        // 后台刷新订阅状态（不阻塞UI）
        await subscriptionManager.refreshSubscriptionStatus()

        print("📦 [SubscriptionView] 订阅状态刷新完成")
    }

    private func getProduct(for period: SubscriptionPeriod, tier: SubscriptionTier) -> Product? {
        let productId: String
        switch (tier, period) {
        case (.explorer, .monthly):
            productId = SubscriptionProduct.explorerMonthly.rawValue
        case (.explorer, .yearly):
            productId = SubscriptionProduct.explorerYearly.rawValue
        case (.lord, .monthly):
            productId = SubscriptionProduct.lordMonthly.rawValue
        case (.lord, .yearly):
            productId = SubscriptionProduct.lordYearly.rawValue
        default:
            return nil
        }

        return subscriptionManager.getProduct(for: productId)
    }

    private func handleSubscribe(_ product: Product) async {
        // 显示确认弹窗
        selectedProduct = product

        // 确定档位
        if product.id.contains("basic") || product.id.contains("explorer") {
            selectedTier = .explorer
        } else if product.id.contains("premium") || product.id.contains("lord") {
            selectedTier = .lord
        }

        showConfirmSheet = true
    }

    private func confirmSubscribe() async {
        guard let product = selectedProduct else { return }

        do {
            try await subscriptionManager.subscribe(product)

            // 订阅成功
            showConfirmSheet = false

            // 获取订阅信息
            let tier = selectedTier ?? .free
            let expiresAt: Date
            if product.id.contains("yearly") {
                expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            } else {
                expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            }

            subscriptionResult = .success(tier: tier, expiresAt: expiresAt)
            showResultView = true

        } catch {
            // 订阅失败
            showConfirmSheet = false

            // 判断错误类型
            if let subscriptionError = error as? SubscriptionError {
                switch subscriptionError {
                case .subscribeFailed(let message) where message.contains("取消"):
                    subscriptionResult = .cancelled
                default:
                    subscriptionResult = .failure(error: error.localizedDescription)
                }
            } else {
                subscriptionResult = .failure(error: error.localizedDescription)
            }

            showResultView = true
        }
    }

    private func cancelSubscribe() {
        showConfirmSheet = false
        selectedProduct = nil
        selectedTier = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum SubscriptionPeriod: String, CaseIterable {
    case monthly = "月卡"
    case yearly = "年卡"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
