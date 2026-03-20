//
//  ResourceRow.swift
//  EarthLord
//
//  资源行组件 - 显示资源需求和当前数量
//

import SwiftUI

/// 资源行组件
struct ResourceRow: View {
    let resourceName: String
    let requiredAmount: Int
    let currentAmount: Int
    let icon: String

    /// 是否资源充足
    var isSufficient: Bool {
        currentAmount >= requiredAmount
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .frame(width: 24)

            // 资源名称
            Text(resourceName)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量显示
            HStack(spacing: 4) {
                Text("\(currentAmount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)

                Text("/")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(requiredAmount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.cardBackground.opacity(0.5))
        )
    }
}

/// 简化版资源行（仅显示需求，不显示当前数量）
struct SimpleResourceRow: View {
    let resourceName: String
    let amount: Int
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)

            Text(resourceName)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text("x\(amount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - 资源图标映射

/// 根据资源 ID 获取图标
func resourceIcon(for resourceId: String) -> String {
    switch resourceId.lowercased() {
    case "wood":
        return "tree.fill"
    case "stone":
        return "mountain.2.fill"
    case "scrap_metal":
        return "gearshape.fill"
    case "glass":
        return "square.fill"
    case "water", "water_bottle":
        return "drop.fill"
    case "food", "canned_food", "bread":
        return "leaf.fill"
    case "cloth":
        return "rectangle.3.group.fill"
    case "nails":
        return "wrench.fill"
    case "rope":
        return "link"
    case "bandage":
        return "cross.fill"
    case "seeds":
        return "sparkle"
    case "tool":
        return "hammer.fill"
    case "toolbox":
        return "briefcase.fill"
    case "fuel":
        return "fuelpump.fill"
    case "electronic_component":
        return "cpu.fill"
    case "satellite_module":
        return "satellite"
    case "blueprint_basic":
        return "doc.fill"
    case "blueprint_epic":
        return "doc.badge.gearshape.fill"
    case "equipment_rare":
        return "shield.fill"
    case "build_speedup":
        return "bolt.fill"
    default:
        return "cube.fill"
    }
}

/// 根据资源 ID 获取本地化名称
func resourceDisplayName(for resourceId: String) -> String {
    switch resourceId.lowercased() {
    case "wood":
        return String(localized: "木材")
    case "stone":
        return String(localized: "石头")
    case "scrap_metal":
        return String(localized: "废金属")
    case "glass":
        return String(localized: "玻璃")
    case "cloth":
        return String(localized: "布料")
    case "nails":
        return String(localized: "钉子")
    case "rope":
        return String(localized: "绳索")
    case "bandage":
        return String(localized: "绷带")
    case "seeds":
        return String(localized: "种子")
    case "tool":
        return String(localized: "工具")
    case "toolbox":
        return String(localized: "工具箱")
    case "fuel":
        return String(localized: "燃料")
    case "electronic_component":
        return String(localized: "电子元件")
    case "satellite_module":
        return String(localized: "卫星模块")
    case "blueprint_basic":
        return String(localized: "基础图纸")
    case "blueprint_epic":
        return String(localized: "史诗图纸")
    case "equipment_rare":
        return String(localized: "稀有装备")
    case "build_speedup":
        return String(localized: "建造加速令")
    case "water", "water_bottle":
        return String(localized: "矿泉水")
    case "food", "canned_food":
        return String(localized: "罐头食品")
    default:
        return resourceId
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ResourceRow(
            resourceName: "木材",
            requiredAmount: 50,
            currentAmount: 80,
            icon: "tree.fill"
        )

        ResourceRow(
            resourceName: "石头",
            requiredAmount: 30,
            currentAmount: 15,
            icon: "mountain.2.fill"
        )

        Divider()
            .background(ApocalypseTheme.textSecondary)

        SimpleResourceRow(
            resourceName: "废金属",
            amount: 20,
            icon: "gearshape.fill"
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
