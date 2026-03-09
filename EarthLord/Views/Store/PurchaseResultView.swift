//
//  PurchaseResultView.swift
//  EarthLord
//
//  购买结果页面
//

import SwiftUI

struct PurchaseResultView: View {
    let isSuccess: Bool
    let message: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // 结果图标
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: iconName)
                            .font(.system(size: 60))
                            .foregroundColor(iconColor)
                    }

                    // 结果文本
                    VStack(spacing: 12) {
                        Text(titleText)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(message)
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    // 成功时显示邮箱提示
                    if isSuccess {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(ApocalypseTheme.primary)
                                Text("store.result.check.mail")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                        }
                    }

                    Spacer()

                    // 关闭按钮
                    Button(action: {
                        dismiss()
                        onDismiss()
                    }) {
                        Text(isSuccess ? String(localized: "store.result.go.mailbox") : String(localized: "store.close"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSuccess ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                            .foregroundColor(isSuccess ? .white : ApocalypseTheme.textPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - 计算属性

    private var titleText: String {
        isSuccess ? String(localized: "store.result.success.title") : String(localized: "store.result.fail.title")
    }

    private var iconName: String {
        isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var iconColor: Color {
        isSuccess ? .green : .red
    }

    private var iconBackgroundColor: Color {
        isSuccess ? .green : .red
    }
}

#Preview {
    VStack {
        PurchaseResultView(
            isSuccess: true,
            message: "购买成功！物品已发送到邮箱，请查收。",
            onDismiss: {}
        )
    }
}
