//
//  MailItemRow.swift
//  EarthLord
//
//  邮件行组件
//

import SwiftUI

struct MailItemRow: View {
    let mail: Mail

    var body: some View {
        HStack(spacing: 12) {
            // 邮件图标
            mailIcon

            // 邮件信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mail.title)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // 时间
                    Text(mail.timeAgo)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 物品数量
                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("\(mail.totalItemCount) 件物品")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let days = mail.daysRemaining, days <= 7 {
                        Text("• \(days)天后过期")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // 状态标签
                HStack(spacing: 6) {
                    if mail.isClaimed {
                        statusBadge(text: "已领取", color: .gray)
                    } else if !mail.isRead {
                        statusBadge(text: "未读", color: .red)
                    }

                    if mail.isExpired {
                        statusBadge(text: "已过期", color: .red)
                    }
                }
            }

            // 未读标记
            if !mail.isRead && !mail.isClaimed {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(mail.isRead ? ApocalypseTheme.cardBackground : ApocalypseTheme.cardBackground.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(mail.isRead ? Color.clear : ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 邮件图标
    private var mailIcon: some View {
        ZStack {
            Circle()
                .fill(mailIconColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: mail.mailType.iconName)
                .font(.system(size: 22))
                .foregroundColor(mailIconColor)
        }
    }

    private var mailIconColor: Color {
        switch mail.mailType {
        case .purchase: return ApocalypseTheme.primary
        case .reward: return .green
        case .gift: return .pink
        }
    }

    // MARK: - 状态标签
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - Mail Extension

extension Mail {
    /// 时间间隔描述
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}
