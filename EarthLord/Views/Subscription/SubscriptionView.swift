//
//  SubscriptionView.swift
//  EarthLord
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    @State private var selectedTier: SubscriptionTier = .explorer
    @State private var isLoading = true
    @State private var isSubscribing = false
    @State private var showConfirmSheet = false
    @State private var showResultView = false
    @State private var selectedProduct: Product?
    @State private var subscriptionResult: SubscriptionResultView.ResultType?

    private let explorerColor = ApocalypseTheme.primary
    private let lordColor = Color(red: 1.0, green: 0.75, blue: 0.1)

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部标题区
                        headerSection

                        VStack(spacing: 20) {
                            // 月卡/年卡切换
                            periodToggle
                                .padding(.horizontal, 20)

                            // 特权对比
                            comparisonSection
                                .padding(.horizontal, 20)

                            // 档位选择
                            tierSelector
                                .padding(.horizontal, 20)

                            // 底部操作区
                            bottomActions
                                .padding(.horizontal, 20)

                            // 订阅说明
                            subscriptionNotice
                                .padding(.horizontal, 20)

                            // 隐私政策 & 用户协议
                            legalLinks
                                .padding(.horizontal, 20)
                                .padding(.bottom, 32)
                        }
                        .padding(.top, 24)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "sub.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "关闭")) { dismiss() }
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .onAppear { Task { await loadData() } }
        .onChange(of: subscriptionManager.availableSubscriptions.count) { _ in
            if !subscriptionManager.availableSubscriptions.isEmpty { isLoading = false }
        }
        .sheet(isPresented: $showConfirmSheet) {
            if let product = selectedProduct {
                SubscriptionConfirmSheet(
                    product: product,
                    tier: selectedTier,
                    onConfirm: { await confirmSubscribe() },
                    onCancel: { cancelSubscribe() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showResultView) {
            if let result = subscriptionResult {
                SubscriptionResultView(result: result, onDismiss: {
                    showResultView = false
                    subscriptionResult = nil
                })
            }
        }
    }

    // MARK: - 顶部标题

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("sub.header.title"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(LocalizedStringKey("sub.header.subtitle"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 月卡/年卡切换

    private var periodToggle: some View {
        HStack(spacing: 0) {
            ForEach(SubscriptionPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedPeriod = period }
                }) {
                    HStack(spacing: 6) {
                        Text(period.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedPeriod == period ? .white : ApocalypseTheme.textSecondary)
                        if period == .yearly {
                            Text(LocalizedStringKey("sub.better.value"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(selectedPeriod == period ? .white.opacity(0.85) : ApocalypseTheme.success)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    selectedPeriod == period
                                        ? Color.white.opacity(0.2)
                                        : ApocalypseTheme.success.opacity(0.15)
                                )
                                .cornerRadius(4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedPeriod == period
                            ? ApocalypseTheme.primary
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 特权对比

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            // 列标题
            HStack(spacing: 0) {
                Text(LocalizedStringKey("sub.perk.header"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(LocalizedStringKey("sub.tier.free"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 60, alignment: .center)

                Text(LocalizedStringKey("sub.tier.explorer.label"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(explorerColor)
                    .frame(width: 60, alignment: .center)

                Text(LocalizedStringKey("sub.tier.lord.label"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(lordColor)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10, corners: [.topLeft, .topRight])

            Divider().background(Color.white.opacity(0.06))

            // 对比行
            Group {
                comparisonRow("backpack.fill",   String(localized: "sub.perk.backpack"),      "100",                                 "500",                                   "1000",                                  highlight: false)
                comparisonRow("map.fill",         String(localized: "sub.perk.range"),         "1km",                                 "2km",                                   "3km",                                   highlight: false)
                comparisonRow("building.2.fill",  String(localized: "sub.perk.build_speed"),   "1x",                                  "2x",                                    "2x",                                    highlight: false)
                comparisonRow("figure.walk",      String(localized: "sub.perk.explorations"),  String(localized: "sub.value.10perday"), String(localized: "sub.value.unlimited"), String(localized: "sub.value.unlimited"), highlight: true)
                comparisonRow("arrow.triangle.2.circlepath", String(localized: "sub.perk.trades"), String(localized: "sub.value.10perday"), String(localized: "sub.value.unlimited"), String(localized: "sub.value.unlimited"), highlight: true)
                comparisonRow("gift.fill",        String(localized: "sub.perk.daily_gift"),    "—",                                   String(localized: "sub.value.5items"),   String(localized: "sub.value.7items"),   highlight: true)
                comparisonRow("tag.fill",         String(localized: "sub.perk.callsign"),      "—",                                   "✓",                                     "✓",                                     highlight: true)
                comparisonRow("crown.fill",       String(localized: "sub.perk.lord_title"),    "—",                                   "—",                                     "✓",                                     highlight: true)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func comparisonRow(_ icon: String, _ label: String, _ free: String, _ explorer: String, _ lord: String, highlight: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(highlight ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 16)
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(free)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 60, alignment: .center)

                Text(explorer)
                    .font(.caption)
                    .fontWeight(explorer == "—" ? .regular : .semibold)
                    .foregroundColor(explorer == "—" ? ApocalypseTheme.textMuted : explorerColor)
                    .frame(width: 60, alignment: .center)

                Text(lord)
                    .font(.caption)
                    .fontWeight(lord == "—" ? .regular : .semibold)
                    .foregroundColor(lord == "—" ? ApocalypseTheme.textMuted : lordColor)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().background(Color.white.opacity(0.04))
        }
    }

    // MARK: - 档位选择

    private var tierSelector: some View {
        VStack(spacing: 12) {
            tierCard(.explorer)
            tierCard(.lord)
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let color: Color = tier == .explorer ? explorerColor : lordColor
        let product = getProduct(for: selectedPeriod, tier: tier)
        let isSelected = selectedTier == tier

        return Button(action: { selectedTier = tier }) {
            HStack(spacing: 14) {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(tier.badgeIcon)
                        .font(.system(size: 22))
                }

                // 中间信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundColor(color)
                    Text(tier.tagline)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    // 权益亮点
                    HStack(spacing: 8) {
                        ForEach(tier.highlights, id: \.self) { h in
                            Text(h)
                                .font(.caption2)
                                .foregroundColor(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                // 右侧价格 + 选中指示
                VStack(alignment: .trailing, spacing: 2) {
                    if let p = product {
                        Text(p.displayPrice)
                            .font(.headline)
                            .foregroundColor(color)
                        Text(selectedPeriod == .monthly ? String(localized: "period.mo.suffix") : String(localized: "period.yr.suffix"))
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? color : ApocalypseTheme.textMuted)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color.white.opacity(0.06),
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: isSelected ? color.opacity(0.2) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 底部操作

    private var bottomActions: some View {
        VStack(spacing: 12) {
            // 立即订阅
            Button(action: { Task { await handleSubscribe() } }) {
                HStack(spacing: 8) {
                    if isSubscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                        Text(String(format: String(localized: "sub.button.subscribe"), selectedTier.displayName, selectedPeriod.displayName))
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [selectedTier == .explorer ? explorerColor : lordColor,
                                 (selectedTier == .explorer ? explorerColor : lordColor).opacity(0.75)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(isSubscribing || getProduct(for: selectedPeriod, tier: selectedTier) == nil)

            // 恢复购买
            Button(action: { Task { try? await subscriptionManager.restorePurchases() } }) {
                Text(LocalizedStringKey("sub.restore"))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 订阅说明

    private var subscriptionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("sub.notice.1"))
            Text(LocalizedStringKey("sub.notice.2"))
            Text(LocalizedStringKey("sub.notice.3"))
            Text(LocalizedStringKey("sub.notice.4"))
        }
        .font(.caption2)
        .foregroundColor(ApocalypseTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    // MARK: - 法律链接

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Spacer()
            Link(String(localized: "sub.privacy_policy"), destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/privacy.html")!)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("·")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
            Link(String(localized: "sub.terms"), destination: URL(string: "https://zhouxiaohong1978.github.io/earthlord-support/terms.html")!)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
            Spacer()
        }
    }

    // MARK: - 方法

    private func loadData() async {
        if !subscriptionManager.availableSubscriptions.isEmpty {
            isLoading = false; return
        }
        if subscriptionManager.isLoadingProducts { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task { await subscriptionManager.loadSubscriptions(); isLoading = false }
        }
    }

    private func getProduct(for period: SubscriptionPeriod, tier: SubscriptionTier) -> Product? {
        let id: String
        switch (tier, period) {
        case (.explorer, .monthly): id = SubscriptionProduct.explorerMonthly.rawValue
        case (.explorer, .yearly):  id = SubscriptionProduct.explorerYearly.rawValue
        case (.lord, .monthly):     id = SubscriptionProduct.lordMonthly.rawValue
        case (.lord, .yearly):      id = SubscriptionProduct.lordYearly.rawValue
        default: return nil
        }
        return subscriptionManager.getProduct(for: id)
    }

    private func handleSubscribe() async {
        guard let product = getProduct(for: selectedPeriod, tier: selectedTier) else { return }
        selectedProduct = product
        showConfirmSheet = true
    }

    private func confirmSubscribe() async {
        guard let product = selectedProduct else { return }
        isSubscribing = true
        do {
            try await subscriptionManager.subscribe(product)
            showConfirmSheet = false
            let expires = product.id.contains("yearly")
                ? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                : Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            subscriptionResult = .success(tier: selectedTier, expiresAt: expires)
            showResultView = true
        } catch {
            showConfirmSheet = false
            if let e = error as? SubscriptionError, case .subscribeFailed(let msg) = e, msg.contains("取消") {
                subscriptionResult = .cancelled
            } else {
                subscriptionResult = .failure(error: error.localizedDescription)
            }
            showResultView = true
        }
        isSubscribing = false
    }

    private func cancelSubscribe() {
        showConfirmSheet = false
        selectedProduct = nil
    }
}

// MARK: - SubscriptionTier 扩展

extension SubscriptionTier {
    var tagline: String {
        switch self {
        case .free:     return String(localized: "tier.free.tagline")
        case .explorer: return String(localized: "tier.explorer.tagline")
        case .lord:     return String(localized: "tier.lord.tagline")
        }
    }

    var highlights: [String] {
        switch self {
        case .free:     return []
        case .explorer: return [
            String(localized: "tier.explorer.h1"),
            String(localized: "tier.explorer.h2"),
            String(localized: "tier.explorer.h3")
        ]
        case .lord:     return [
            String(localized: "tier.lord.h1"),
            String(localized: "tier.lord.h2"),
            String(localized: "tier.lord.h3")
        ]
        }
    }
}

// MARK: - RoundedCorner 辅助

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

enum SubscriptionPeriod: String, CaseIterable {
    case monthly = "monthly"
    case yearly  = "yearly"

    var displayName: String {
        switch self {
        case .monthly: return String(localized: "period.monthly")
        case .yearly:  return String(localized: "period.yearly")
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
