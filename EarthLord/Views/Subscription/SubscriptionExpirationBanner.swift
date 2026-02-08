//
//  SubscriptionExpirationBanner.swift
//  EarthLord
//
//  订阅过期提醒横幅
//

import SwiftUI

struct SubscriptionExpirationBanner: View {

    // MARK: - Properties

    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscriptionView = false
    @State private var isDismissed = false

    // MARK: - Body

    var body: some View {
        if shouldShowBanner && !isDismissed {
            bannerContent
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: bannerIcon)
                .font(.title3)
                .foregroundColor(bannerColor)

            // 文本
            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let message = subscriptionManager.expirationMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 续费按钮
            if subscriptionManager.isExpired || subscriptionManager.isExpiringSoon {
                Button(action: {
                    showSubscriptionView = true
                }) {
                    Text("续费")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(bannerColor)
                        )
                }
            }

            // 关闭按钮
            Button(action: {
                withAnimation {
                    isDismissed = true
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(bannerColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(bannerColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .sheet(isPresented: $showSubscriptionView) {
            NavigationStack {
                SubscriptionView()
            }
        }
    }

    // MARK: - Computed Properties

    private var shouldShowBanner: Bool {
        subscriptionManager.isExpired || subscriptionManager.isExpiringSoon
    }

    private var bannerIcon: String {
        if subscriptionManager.isExpired {
            return "exclamationmark.triangle.fill"
        } else {
            return "clock.badge.exclamationmark.fill"
        }
    }

    private var bannerColor: Color {
        if subscriptionManager.isExpired {
            return ApocalypseTheme.danger
        } else {
            return ApocalypseTheme.warning
        }
    }

    private var bannerTitle: String {
        if subscriptionManager.isExpired {
            return "订阅已过期"
        } else {
            return "订阅即将过期"
        }
    }
}

// MARK: - Preview

#Preview("即将过期") {
    VStack {
        SubscriptionExpirationBanner()
        Spacer()
    }
    .background(ApocalypseTheme.background)
}

#Preview("已过期") {
    VStack {
        SubscriptionExpirationBanner()
        Spacer()
    }
    .background(ApocalypseTheme.background)
}
