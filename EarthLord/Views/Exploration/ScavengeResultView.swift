//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示弹窗 - 显示玩家搜刮POI获得的物品
//

import SwiftUI
import CoreLocation

struct ScavengeResultView: View {
    let result: ScavengeResult
    let onConfirm: () -> Void
    let onDiscard: () -> Void

    @State private var showItems = false

    var body: some View {
        VStack(spacing: 24) {
            // 标题区域
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ApocalypseTheme.success)

                Text("搜刮完成!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    Image(systemName: result.poi.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(result.poi.type.color)

                    Text(result.poi.name)
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // 获得物品标题
            HStack {
                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(result.items.count) 件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 20)

            // 物品列表
            VStack(spacing: 12) {
                ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                    ItemRow(item: item)
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1),
                            value: showItems
                        )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // 按钮
            VStack(spacing: 12) {
                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 16))
                        Text("收下物品")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }

                Button {
                    onDiscard()
                } label: {
                    Text("放弃物品")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, 24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showItems = true
            }
        }
    }
}

// MARK: - 物品行组件

struct ItemRow: View {
    let item: ObtainedItem

    /// 获取物品定义
    private var itemDefinition: ItemDefinition? {
        MockExplorationData.getItemDefinition(by: item.itemId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(rarityColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(itemDefinition?.name ?? item.itemId)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    // 稀有度
                    if let definition = itemDefinition {
                        Text(definition.rarity.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(rarityColor)
                    }

                    // 品质
                    if let quality = item.quality {
                        Text(quality.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(qualityColor(quality))
                    }
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        guard let definition = itemDefinition else { return ApocalypseTheme.textMuted }

        switch definition.rarity {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }

    /// 分类图标
    private var categoryIcon: String {
        guard let definition = itemDefinition else { return "cube.fill" }

        switch definition.category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.fill"
        case .weapon:
            return "bolt.fill"
        case .clothing:
            return "tshirt.fill"
        case .misc:
            return "archivebox.fill"
        }
    }

    /// 品质颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .broken:
            return .red
        case .worn:
            return .orange
        case .normal:
            return .gray
        case .good:
            return .green
        case .excellent:
            return .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        ScavengeResultView(
            result: ScavengeResult(
                poi: POI(
                    name: "废弃超市",
                    type: .supermarket,
                    coordinate: .init(latitude: 0, longitude: 0),
                    status: .hasResources,
                    description: "可能有食物和水"
                ),
                items: [
                    ObtainedItem(itemId: "water_bottle", quantity: 2, quality: nil),
                    ObtainedItem(itemId: "canned_food", quantity: 1, quality: .good),
                    ObtainedItem(itemId: "bandage", quantity: 3, quality: .normal)
                ],
                sessionId: "test"
            ),
            onConfirm: {},
            onDiscard: {}
        )
    }
}
