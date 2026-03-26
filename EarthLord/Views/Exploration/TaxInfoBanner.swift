//
//  TaxInfoBanner.swift
//  EarthLord
//
//  在他人领地搜刮后显示的税收提示横幅
//

import SwiftUI

struct TaxInfoBanner: View {
    let info: TaxInfo
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 税收信息行
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "已进入「%@」"), info.ownerName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(String(format: String(localized: "领地税收 %d%% · 扣除 %d 件物品"), info.taxRate, info.taxCount))
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            // 领主广播消息
            if let msg = info.broadcastMessage, !msg.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(3)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.primary.opacity(0.1))
                )
            }

            // 前往通讯按钮
            Button {
                onDismiss()
                NotificationCenter.default.post(name: .switchToCommunicationTab, object: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13))
                    Text(LocalizedStringKey("前往通讯频道"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.primary.opacity(0.12))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.4), radius: 12)
        )
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                onDismiss()
            }
        }
    }
}
