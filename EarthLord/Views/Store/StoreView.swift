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
    /// 跳转到地图Tab的通知
    static let navigateToMapTab = Notification.Name("navigateToMapTab")
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
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if purchaseManager.isLoadingProducts {
                loadingView
            } else if purchaseManager.availableProducts.isEmpty {
                emptyView
            } else {
                productsView
            }
        }
        .navigationTitle(Text("store.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Text("store.close")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showingPurchaseConfirm) {
            if let product = selectedProduct {
                PurchaseConfirmSheet(
                    product: product,
                    onConfirm: {
                        Task { await handlePurchase(product) }
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
                    if purchaseResultSuccess {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .navigateToMailbox, object: nil)
                        }
                    }
                }
            )
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await purchaseManager.loadProducts()
            }
        }
    }

    // MARK: - 商品列表
    private var productsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部提示
                infoCard

                // Slogan
                sloganBanner

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

    // MARK: - Slogan 横幅
    private var sloganBanner: some View {
        Text("store.slogan")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ApocalypseTheme.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.primary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(ApocalypseTheme.primary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 提示卡片
    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("store.info.title")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("store.info.desc")
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
            Text("store.loading")
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

            Text("store.empty")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("store.empty.retry")
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
                purchaseResultMessage = String(localized: "store.purchase.success")
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
            purchaseResultMessage = "\(String(localized: "error.purchase.failed"))：\(error.localizedDescription)"
            showingPurchaseResult = true
        }
    }
}

#Preview {
    StoreView()
}
