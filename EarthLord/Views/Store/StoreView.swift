//
//  StoreView.swift
//  EarthLord
//
//  商城主页
//

import SwiftUI
import StoreKit

// MARK: - 通知名称扩展

extension Notification.Name {
    /// 跳转到邮箱的通知
    static let navigateToMailbox = Notification.Name("navigateToMailbox")
}

struct StoreView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showingPurchaseConfirm = false
    @State private var showingPurchaseResult = false
    @State private var purchaseResultSuccess = false
    @State private var purchaseResultMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 导航栏
                    navigationBar

                    if purchaseManager.isLoadingProducts {
                        loadingView
                    } else if purchaseManager.availableProducts.isEmpty {
                        emptyView
                    } else {
                        productsView
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPurchaseConfirm) {
                if let product = selectedProduct {
                    PurchaseConfirmSheet(
                        product: product,
                        onConfirm: {
                            Task {
                                await handlePurchase(product)
                            }
                        },
                        onCancel: {
                            showingPurchaseConfirm = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingPurchaseResult) {
                PurchaseResultView(
                    isSuccess: purchaseResultSuccess,
                    message: purchaseResultMessage,
                    onDismiss: {
                        showingPurchaseResult = false
                        // 购买成功时，发送通知跳转到邮箱
                        if purchaseResultSuccess {
                            dismiss() // 先关闭商城
                            // 延迟发送通知，确保商城已关闭
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: .navigateToMailbox, object: nil)
                            }
                        }
                    }
                )
            }
        }
        .onAppear {
            // 延迟1秒加载商品，避免与其他初始化操作并发导致真机崩溃
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await purchaseManager.loadProducts()
            }
        }
    }

    // MARK: - 导航栏
    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text("商城")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 恢复购买按钮
            Button(action: {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 商品列表
    private var productsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部提示
                infoCard

                // 物资包列表
                ForEach(purchaseManager.availableProducts, id: \.id) { product in
                    SupplyPackCard(product: product) {
                        selectedProduct = product
                        showingPurchaseConfirm = true
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 提示卡片
    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("购买说明")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("购买的物品将发送到邮箱，请及时领取")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载商品中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 空状态
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无商品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请稍后再试")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 购买处理
    private func handlePurchase(_ product: Product) async {
        showingPurchaseConfirm = false

        do {
            try await purchaseManager.purchase(product)

            // 检查购买状态
            switch purchaseManager.purchaseState {
            case .success:
                purchaseResultSuccess = true
                purchaseResultMessage = "购买成功！物品已发送到邮箱，请查收。"
                showingPurchaseResult = true

            case .cancelled:
                // 用户取消，不显示结果
                break

            case .failed(let error):
                purchaseResultSuccess = false
                purchaseResultMessage = error.localizedDescription
                showingPurchaseResult = true

            default:
                break
            }

        } catch {
            purchaseResultSuccess = false
            purchaseResultMessage = "购买失败：\(error.localizedDescription)"
            showingPurchaseResult = true
        }
    }
}

#Preview {
    StoreView()
}
