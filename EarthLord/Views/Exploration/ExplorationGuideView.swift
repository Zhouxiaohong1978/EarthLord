//
//  ExplorationGuideView.swift
//  EarthLord
//
//  探索新手引导页 - 点击「开始探索」时弹出，首次必读，后续可跳过
//

import SwiftUI

struct ExplorationGuideView: View {

    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = false

    private static let hasShownKey = "hasShownExplorationGuide"

    /// 是否已经看过引导（用于外部判断是否需要弹出）
    static var hasShown: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownKey) }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: 标题
                    VStack(alignment: .leading, spacing: 6) {
                        Text("探索指南")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("出门前先了解这两件事，物品到手更多")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 8)

                    // MARK: 距离奖励
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "figure.walk", title: "距离奖励", subtitle: "走得越远，物品越多、品质越高")

                            VStack(spacing: 8) {
                                rewardRow(icon: "medal",        color: Color(red: 0.6, green: 0.4, blue: 0.2), tier: "铜级", range: "200m+",  items: "2件", quality: "普通为主")
                                rewardRow(icon: "medal.fill",   color: Color.gray,                             tier: "银级", range: "500m+",  items: "3件", quality: "含稀有")
                                rewardRow(icon: "star.fill",    color: Color.yellow,                           tier: "金级", range: "1km+",   items: "5件", quality: "含史诗")
                                rewardRow(icon: "sparkles",     color: Color.cyan,                             tier: "钻石", range: "2km+",   items: "7件", quality: "高品质")
                                rewardRow(icon: "crown.fill",   color: Color.purple,                           tier: "传奇", range: "5km+",   items: "10件", quality: "全类型")
                            }
                        }
                    }

                    // MARK: 废墟搜刮
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "mappin.and.ellipse", title: "废墟搜刮", subtitle: "地图上的废墟可额外获得物品")

                            VStack(alignment: .leading, spacing: 10) {
                                tipRow(number: "1", text: "开始探索后，地图显示附近可搜刮废墟（医院、超市、药店等）")
                                tipRow(number: "2", text: "累计步行满 500m 后，走进废墟 50m 范围内触发搜刮弹窗")
                                tipRow(number: "3", text: "每处废墟搜刮后进入冷却，可继续去下一处")
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.info)
                                Text("搜刮进度显示在探索状态栏，走满 500m 自动解锁")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.info.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    // MARK: 小技巧
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "lightbulb.fill", title: "小技巧", subtitle: "让每次探索收益最大化")

                            VStack(alignment: .leading, spacing: 8) {
                                bulletRow("医院、超市稀有物品概率更高")
                                bulletRow("周围玩家越少，物资质量越好")
                                bulletRow("步行距离越远，稀有度和数量同步提升")
                                bulletRow("升级订阅可见更多废墟，物品数量也有倍率加成")
                            }
                        }
                    }

                    // MARK: 不再显示 + 开始按钮
                    VStack(spacing: 12) {
                        Button {
                            dontShowAgain.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                    .foregroundColor(dontShowAgain ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                                Text("下次不再显示")
                                    .font(.system(size: 14))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }

                        Button {
                            if dontShowAgain {
                                ExplorationGuideView.hasShown = true
                            }
                            dismiss()
                            onStart()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.walk.motion")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("明白了，开始探索！")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - 子组件

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    private func rewardRow(icon: String, color: Color, tier: String, range: String, items: String, quality: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            Text(tier)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, alignment: .leading)
            Text(range)
                .font(.system(size: 13).monospacedDigit())
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 50, alignment: .leading)
            Spacer()
            Text(items)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(quality)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }

    private func tipRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20, height: 20)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ExplorationGuideView(onStart: {})
}
