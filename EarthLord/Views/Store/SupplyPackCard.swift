//
//  SupplyPackCard.swift
//  EarthLord
//
//  物资包卡片组件 - 每个礼包有独立视觉主题
//

import SwiftUI
import StoreKit

// MARK: - 礼包视觉主题

private struct PackTheme {
    let accentColor: Color
    let secondaryColor: Color
    let headerGradient: [Color]
    let icon: String
    let badgeIcon: String
    let tierLabel: String
    let tierLabelColor: Color
    let taglineKey: String    // 本地化 key，随系统语言切换
}

private func theme(for productId: String) -> PackTheme {
    switch productId {
    case "com.earthlord.survivor_pack":
        return PackTheme(
            accentColor: Color(red: 0.29, green: 0.69, blue: 0.31),
            secondaryColor: Color(red: 0.20, green: 0.50, blue: 0.22),
            headerGradient: [
                Color(red: 0.10, green: 0.22, blue: 0.12),
                Color(red: 0.08, green: 0.08, blue: 0.09)
            ],
            icon: "leaf.fill",
            badgeIcon: "🌿",
            tierLabel: "TIER 1",
            tierLabelColor: Color(red: 0.29, green: 0.69, blue: 0.31),
            taglineKey: "pack.survivor.tagline"
        )
    case "com.earthlord.constructor_pack":
        return PackTheme(
            accentColor: Color(red: 0.95, green: 0.62, blue: 0.12),
            secondaryColor: Color(red: 0.75, green: 0.44, blue: 0.06),
            headerGradient: [
                Color(red: 0.25, green: 0.16, blue: 0.04),
                Color(red: 0.08, green: 0.08, blue: 0.09)
            ],
            icon: "hammer.fill",
            badgeIcon: "🔨",
            tierLabel: "TIER 2",
            tierLabelColor: Color(red: 0.95, green: 0.62, blue: 0.12),
            taglineKey: "pack.constructor.tagline"
        )
    case "com.earthlord.engineer_pack":
        return PackTheme(
            accentColor: Color(red: 0.05, green: 0.74, blue: 0.95),
            secondaryColor: Color(red: 0.02, green: 0.52, blue: 0.72),
            headerGradient: [
                Color(red: 0.02, green: 0.16, blue: 0.25),
                Color(red: 0.08, green: 0.08, blue: 0.09)
            ],
            icon: "cpu.fill",
            badgeIcon: "⚡️",
            tierLabel: "TIER 3",
            tierLabelColor: Color(red: 0.05, green: 0.74, blue: 0.95),
            taglineKey: "pack.engineer.tagline"
        )
    case "com.earthlord.rare_pack":
        return PackTheme(
            accentColor: Color(red: 0.80, green: 0.55, blue: 1.00),
            secondaryColor: Color(red: 0.58, green: 0.18, blue: 0.88),
            headerGradient: [
                Color(red: 0.18, green: 0.06, blue: 0.28),
                Color(red: 0.08, green: 0.08, blue: 0.09)
            ],
            icon: "crown.fill",
            badgeIcon: "👑",
            tierLabel: "LEGENDARY",
            tierLabelColor: Color(red: 1.00, green: 0.84, blue: 0.20),
            taglineKey: "pack.rare.tagline"
        )
    default:
        return PackTheme(
            accentColor: ApocalypseTheme.primary,
            secondaryColor: ApocalypseTheme.primary.opacity(0.7),
            headerGradient: [ApocalypseTheme.cardBackground, ApocalypseTheme.background],
            icon: "shippingbox.fill",
            badgeIcon: "📦",
            tierLabel: "PACK",
            tierLabelColor: ApocalypseTheme.primary,
            taglineKey: ""
        )
    }
}

// MARK: - 主卡片

struct SupplyPackCard: View {
    let product: Product
    let onPurchase: () -> Void

    private var packConfig: SupplyPackConfig? {
        guard let packProduct = SupplyPackProduct(rawValue: product.id) else { return nil }
        return SupplyPackConfig.all[packProduct]
    }

    private var t: PackTheme { theme(for: product.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── 彩色头部区域 ──
            headerSection

            // ── 物品列表 ──
            VStack(alignment: .leading, spacing: 12) {
                if let config = packConfig {
                    itemsSection(config: config)
                }

                // 购买按钮
                buyButton
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(t.accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: t.accentColor.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    // MARK: 头部

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // 渐变背景
            LinearGradient(
                colors: t.headerGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 右侧大图标装饰
            HStack {
                Spacer()
                Image(systemName: t.icon)
                    .font(.system(size: 72, weight: .black))
                    .foregroundColor(t.accentColor.opacity(0.12))
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }

            // 左侧文字内容
            VStack(alignment: .leading, spacing: 6) {
                // 档位标签
                Text(t.tierLabel)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(t.tierLabelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(t.tierLabelColor.opacity(0.15))
                    .clipShape(Capsule())

                // 礼包名称
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: t.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(t.accentColor)

                    Text(product.displayName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                }

                // 价格
                Text(product.displayPrice)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(t.accentColor)

                // 特色说明（随系统语言）
                if !t.taglineKey.isEmpty {
                    Text(LocalizedStringKey(t.taglineKey))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 150)
    }

    // MARK: 物品列表

    @ViewBuilder
    private func itemsSection(config: SupplyPackConfig) -> some View {
        // 基础物品
        VStack(alignment: .leading, spacing: 6) {
            Label("store.contains", systemImage: "shippingbox")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ForEach(config.baseItems, id: \.itemId) { item in
                ThemedItemRow(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality,
                    accentColor: t.accentColor
                )
            }
        }

        // 额外奖励
        if !config.bonusItems.isEmpty {
            Divider().background(t.accentColor.opacity(0.2))

            VStack(alignment: .leading, spacing: 6) {
                Label("store.bonus.label", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(t.accentColor)

                ForEach(config.bonusItems, id: \.item.itemId) { bonus in
                    HStack(spacing: 4) {
                        ThemedItemRow(
                            itemId: bonus.item.itemId,
                            quantity: bonus.item.quantity,
                            quality: bonus.item.quality,
                            accentColor: t.accentColor
                        )
                        Spacer()
                        Text("\(bonus.probability)%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(t.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(t.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: 购买按钮

    private var buyButton: some View {
        Button(action: onPurchase) {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("store.buy")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [t.accentColor, t.secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: t.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - 主题物品行

struct ThemedItemRow: View {
    let itemId: String
    let quantity: Int
    let quality: String?
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: itemIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 18)

            Text(LocalizedStringKey("item.\(itemId)"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("×\(quantity)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(accentColor)

            if let quality = quality {
                Text(quality)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(qualityColor(quality))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(qualityColor(quality).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var itemIcon: String {
        switch itemId {
        case "water_bottle": return "drop.fill"
        case "canned_food", "bread": return "fork.knife"
        case "bandage", "medicine", "first_aid_kit", "antibiotics": return "cross.case.fill"
        case "wood": return "tree.fill"
        case "stone": return "mountain.2.fill"
        case "cloth": return "tshirt.fill"
        case "scrap_metal", "nails": return "wrench.fill"
        case "rope": return "link"
        case "tool", "toolbox": return "hammer.fill"
        case "fuel": return "flame.fill"
        case "electronic_component": return "cpu.fill"
        case "satellite_module": return "antenna.radiowaves.left.and.right"
        case "blueprint_basic", "blueprint_epic": return "doc.plaintext.fill"
        case "build_speedup": return "bolt.fill"
        case "equipment_rare", "equipment_epic": return "shield.fill"
        case "scavenge_pass": return "key.fill"
        default: return "cube.box.fill"
        }
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality.lowercased() {
        case "legendary": return .purple
        case "epic":      return .orange
        case "rare":      return .blue
        case "good":      return .green
        default:          return ApocalypseTheme.textSecondary
        }
    }
}

// MARK: - 旧组件保留兼容

struct PackItemRow: View {
    let itemId: String
    let quantity: Int
    let quality: String?

    var body: some View {
        ThemedItemRow(
            itemId: itemId,
            quantity: quantity,
            quality: quality,
            accentColor: ApocalypseTheme.primary
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("物资商城预览")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
