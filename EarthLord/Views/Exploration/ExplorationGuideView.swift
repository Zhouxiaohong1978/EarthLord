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
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: 标题
                    VStack(alignment: .leading, spacing: 6) {
                        Text("探索指南")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("出门前先了解规则，每次探索收益最大化")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 8)

                    // MARK: 距离奖励
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "figure.walk", title: "步行距离奖励", subtitle: "走得越远，物品越多、品质越高")

                            VStack(spacing: 8) {
                                rewardRow(
                                    icon: "medal",
                                    color: Color(red: 0.6, green: 0.4, blue: 0.2),
                                    tier: "铜级", range: "200m+",
                                    base: "2件", multiplied: "×1.5→3 / ×2→4"
                                )
                                rewardRow(
                                    icon: "medal.fill",
                                    color: Color.gray,
                                    tier: "银级", range: "500m+",
                                    base: "3件", multiplied: "×1.5→5 / ×2→6"
                                )
                                rewardRow(
                                    icon: "star.fill",
                                    color: Color.yellow,
                                    tier: "金级", range: "1km+",
                                    base: "5件", multiplied: "×1.5→8 / ×2→10"
                                )
                                rewardRow(
                                    icon: "sparkles",
                                    color: Color.cyan,
                                    tier: "钻石", range: "2km+",
                                    base: "7件", multiplied: "×1.5→11 / ×2→14"
                                )
                                rewardRow(
                                    icon: "crown.fill",
                                    color: Color.purple,
                                    tier: "传奇", range: "5km+",
                                    base: "10件", multiplied: "×1.5→15 / ×2→20"
                                )
                            }

                            // 倍率说明
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.warning)
                                Text("探索者订阅 ×1.5 倍 · 领主订阅 ×2 倍物品数量")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.warning.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }

                    // MARK: 废墟搜刮
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "mappin.and.ellipse", title: "废墟搜刮", subtitle: "靠近废墟额外获得 AI 生成的末日物资")

                            VStack(alignment: .leading, spacing: 10) {
                                tipRow(number: "1", text: "开始探索后，地图自动显示附近废墟（医院、超市、工厂、药店等）")
                                tipRow(number: "2", text: "步行满 500m 后，走进废墟 50m 范围即可触发搜刮弹窗")
                                tipRow(number: "3", text: "每处废墟搜刮后进入冷却，可继续前往下一处")
                                tipRow(number: "4", text: "在他人领地范围内搜刮，系统将自动扣除税收并投递至领主邮箱")
                            }

                            // 档位对比表
                            VStack(spacing: 0) {
                                tierCompareHeader()
                                tierCompareRow(
                                    icon: "person.fill",
                                    tier: "幸存者",
                                    color: .gray,
                                    poi: "2个",
                                    radius: "1km",
                                    cooldown: "24h冷却"
                                )
                                Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                                tierCompareRow(
                                    icon: "binoculars.fill",
                                    tier: "探索者",
                                    color: .blue,
                                    poi: "4个",
                                    radius: "2km",
                                    cooldown: "12h冷却"
                                )
                                Divider().background(ApocalypseTheme.textMuted.opacity(0.2))
                                tierCompareRow(
                                    icon: "crown.fill",
                                    tier: "领主",
                                    color: Color(red: 1.0, green: 0.6, blue: 0.0),
                                    poi: "8个",
                                    radius: "3km",
                                    cooldown: "6h冷却"
                                )
                            }
                            .background(ApocalypseTheme.background.opacity(0.6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ApocalypseTheme.textMuted.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    // MARK: 搜刮令（远程搜刮）
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "key.fill", title: "搜刮令", subtitle: "无需步行到现场，远程解锁废墟物资")

                            VStack(alignment: .leading, spacing: 10) {
                                tipRow(number: "1", text: "背包中有「搜刮令」时，可对任意废墟发起远程搜刮，无需步行前往")
                                tipRow(number: "2", text: "搜刮令消耗后，废墟正常进入冷却计时")
                                tipRow(number: "3", text: "搜刮令可通过购买「资源包」获得，支持的包含：建造者包、工程师包、稀有物资包")
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.primary)
                                Text("前往「个人」→「订阅与商城」购买资源包")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.primary.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }

                    // MARK: 每日限制 & 注意事项
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "exclamationmark.triangle.fill", title: "限制 & 注意事项", subtitle: "了解这些，避免探索中断")

                            VStack(alignment: .leading, spacing: 8) {
                                bulletRow(icon: "calendar.badge.clock", color: .orange,
                                          text: "幸存者每日最多探索 10 次，订阅后无限次数")
                                bulletRow(icon: "speedometer", color: .red,
                                          text: "移动速度超过 20km/h 将触发超速警告，连续 3 次自动终止探索")
                                bulletRow(icon: "location.fill", color: .blue,
                                          text: "探索期间开启后台定位，锁屏后仍正常记录步行距离")
                                bulletRow(icon: "building.2.fill", color: .gray,
                                          text: "在室内或建筑物内长时间停留且速度为零，系统会提醒并可能自动停止")
                                bulletRow(icon: "xmark.circle.fill", color: .red,
                                          text: "主动取消探索不发放距离奖励，已搜刮的物品仍保留")
                            }
                        }
                    }

                    // MARK: 小技巧
                    sectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(icon: "lightbulb.fill", title: "小技巧", subtitle: "让每次探索收益最大化")

                            VStack(alignment: .leading, spacing: 8) {
                                bulletRow(icon: "cross.fill", color: .red,
                                          text: "医院含药品、医疗器械等高稀有度物资，优先搜刮")
                                bulletRow(icon: "cart.fill", color: .green,
                                          text: "超市/便利店食物和水多，早期生存必备")
                                bulletRow(icon: "wrench.fill", color: .orange,
                                          text: "工厂/仓库有建造材料，快速升级建筑的关键")
                                bulletRow(icon: "figure.walk.motion", color: .cyan,
                                          text: "向远处走再返回，步行距离照算，可冲传奇奖励再搜刮近处废墟")
                                bulletRow(icon: "crown.fill", color: Color(red: 1.0, green: 0.6, blue: 0.0),
                                          text: "探索中升级订阅立即生效：新废墟自动追加到地图，奖励倍率同步锁定")
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

    private func sectionHeader(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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

    private func rewardRow(icon: String, color: Color, tier: LocalizedStringKey, range: String, base: LocalizedStringKey, multiplied: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 18)
            Text(tier)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, alignment: .leading)
            Text(range)
                .font(.system(size: 12).monospacedDigit())
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 46, alignment: .leading)
            Spacer()
            Text(base)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(multiplied)
                .font(.system(size: 10))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }

    private func tierCompareHeader() -> some View {
        HStack {
            Text("档位")
                .frame(width: 58, alignment: .leading)
            Spacer()
            Text("废墟数")
                .frame(width: 50, alignment: .center)
            Text("搜索范围")
                .frame(width: 60, alignment: .center)
            Text("冷却")
                .frame(width: 55, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(ApocalypseTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background)
    }

    private func tierCompareRow(icon: String, tier: LocalizedStringKey, color: Color, poi: LocalizedStringKey, radius: String, cooldown: LocalizedStringKey) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(tier)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 58, alignment: .leading)
            Spacer()
            Text(poi)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(width: 50, alignment: .center)
            Text(radius)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 60, alignment: .center)
            Text(cooldown)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func tipRow(number: String, text: LocalizedStringKey) -> some View {
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

    private func bulletRow(icon: String, color: Color, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16, height: 16)
                .padding(.top, 1)
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
