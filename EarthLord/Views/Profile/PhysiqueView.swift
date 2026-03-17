//
//  PhysiqueView.swift
//  EarthLord
//
//  体征视图 - 激活增益 / 警告卡 / 核心生命 / 基础体征

import SwiftUI

struct PhysiqueView: View {
    @StateObject private var manager = PhysiqueManager.shared
    private var lm: LanguageManager { LanguageManager.shared }

    var body: some View {
        VStack(spacing: 12) {
            activeBuffsCard

            if manager.hasWarning {
                warningCard
            }

            coreLifeCard
            basicVitalsCard
        }
        .task { await manager.load() }
    }

    // MARK: - 激活的增益

    private var activeBuffsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text(lm.localizedString(for: "激活的增益"))
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            if let buffKey = manager.subscriptionBuffKey {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(ApocalypseTheme.success)
                    Text(lm.localizedString(for: buffKey))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.success.opacity(0.1)))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(lm.localizedString(for: "没有激活的增益"))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(lm.localizedString(for: "使用食物、水或药品获得增益"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 警告卡

    private var warningCard: some View {
        let isDying = manager.status == .dying
        let hours   = manager.hoursUntilDeath
        let timeStr = hours < 24
            ? String(format: lm.localizedString(for: "%.0f 小时"), hours)
            : String(format: lm.localizedString(for: "%d 天"),     manager.daysUntilDeath)

        return HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(lm.localizedString(for: "Critical Life Warning"))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.white)
                Text(lm.localizedString(for: manager.warningDescKey))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeStr)
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.white)
                Text(lm.localizedString(for: "Until Death"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDying ? ApocalypseTheme.danger : ApocalypseTheme.warning)
        )
    }

    // MARK: - 核心生命

    private var coreLifeCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(ApocalypseTheme.danger)
                Text(lm.localizedString(for: "核心生命"))
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Text(String(format: "%.0f/100", manager.coreLife))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(manager.coreLife < 30 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(lifeBarColor)
                        .frame(width: geo.size.width * CGFloat(manager.coreLife / 100), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: manager.coreLife)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(manager.coreLife < 30 ? ApocalypseTheme.danger.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - 基础体征

    private var basicVitalsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(ApocalypseTheme.danger)
                Text(lm.localizedString(for: "基础体征"))
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Circle().fill(manager.status.color).frame(width: 8, height: 8)
                Text(lm.localizedString(for: manager.status.labelKey))
                    .font(.caption)
                    .foregroundColor(manager.status.color)
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.08))

            vitalRow(
                icon: "fork.knife",
                iconColor: Color(red: 0.85, green: 0.6, blue: 0.2),
                nameKey: "饱食度",
                value: manager.satiety,
                barColor: Color(red: 0.85, green: 0.6, blue: 0.2)
            )

            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

            vitalRow(
                icon: "drop.fill",
                iconColor: ApocalypseTheme.info,
                nameKey: "水分",
                value: manager.hydration,
                barColor: ApocalypseTheme.info
            )

            Divider().background(Color.white.opacity(0.06))

            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.warning)
                Text(lm.localizedString(for: "饱食度/水分>80时获得增益，请及时补给"))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func vitalRow(icon: String, iconColor: Color, nameKey: String, value: Double, barColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lm.localizedString(for: nameKey))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", value))
                        .font(.caption)
                        .foregroundColor(value < 30 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value < 30 ? ApocalypseTheme.danger : barColor)
                            .frame(width: geo.size.width * CGFloat(value / 100), height: 6)
                            .animation(.easeInOut(duration: 0.5), value: value)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var lifeBarColor: Color {
        if manager.coreLife >= 60 { return ApocalypseTheme.success }
        if manager.coreLife >= 35 { return ApocalypseTheme.warning }
        return ApocalypseTheme.danger
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background.ignoresSafeArea()
        ScrollView {
            PhysiqueView().padding(16)
        }
    }
}
