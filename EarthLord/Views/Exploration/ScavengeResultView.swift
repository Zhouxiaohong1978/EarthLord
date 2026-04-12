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
    let onConfirm: (Set<UUID>) -> Void
    let onDiscard: () -> Void

    @ObservedObject private var inventoryManager = InventoryManager.shared
    @State private var selectedItemIds: Set<UUID> = []
    @State private var showItems = false
    @State private var showSubscription = false

    private var remainingCapacity: Int {
        max(0, inventoryManager.backpackCapacity - inventoryManager.totalItemCount)
    }

    private var selectedTotalQuantity: Int {
        result.items
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.quantity }
    }

    private var isOverCapacity: Bool {
        selectedTotalQuantity > remainingCapacity
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题区域
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ApocalypseTheme.success)

                    Text(LocalizedStringKey("搜刮完成!"))
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

                // 背包容量状态
                capacityBanner

                // 获得物品标题
                HStack {
                    Text(LocalizedStringKey("获得物品"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    Text(String(format: String(localized: "已选 %d/%d 件"), selectedItemIds.count, result.items.count))
                        .font(.system(size: 14))
                        .foregroundColor(isOverCapacity ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 20)

                // 物品列表（带勾选）
                VStack(spacing: 12) {
                    ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                        SelectableAIItemRow(
                            item: item,
                            isSelected: selectedItemIds.contains(item.id)
                        ) {
                            if selectedItemIds.contains(item.id) {
                                selectedItemIds.remove(item.id)
                            } else {
                                selectedItemIds.insert(item.id)
                            }
                        }
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1),
                            value: showItems
                        )
                    }
                }
                .padding(.horizontal, 20)

                // 按钮区域
                VStack(spacing: 10) {
                    // 超出容量警告
                    if isOverCapacity {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(String(format: String(localized: "已选 %d 件超出剩余容量 %d 格，请取消勾选"), selectedTotalQuantity, remainingCapacity))
                                .font(.system(size: 12))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.horizontal, 20)
                    }

                    // 收下物品按钮
                    Button {
                        onConfirm(selectedItemIds)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 16))
                            Text(selectedItemIds.isEmpty ? LocalizedStringKey("不收任何物品") : LocalizedStringKey("收下选中物品"))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isOverCapacity ? ApocalypseTheme.textMuted.opacity(0.5) : (selectedItemIds.isEmpty ? ApocalypseTheme.warning : ApocalypseTheme.primary))
                        .cornerRadius(12)
                    }
                    .disabled(isOverCapacity)
                    .padding(.horizontal, 20)

                    // 升级背包容量
                    Button {
                        showSubscription = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 14))
                            Text(LocalizedStringKey("升级背包容量"))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                    }

                    // 放弃全部
                    Button {
                        onDiscard()
                    } label: {
                        Text(LocalizedStringKey("放弃全部物品"))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, 24)
        .onAppear {
            // 默认选中能装下的物品（按顺序贪心）
            var count = 0
            for item in result.items {
                if count + item.quantity <= remainingCapacity {
                    selectedItemIds.insert(item.id)
                    count += item.quantity
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showItems = true
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - 背包容量横幅

    private var capacityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bag.fill")
                .font(.system(size: 14))
                .foregroundColor(remainingCapacity == 0 ? ApocalypseTheme.danger : ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(remainingCapacity == 0
                     ? String(localized: "背包已满")
                     : String(format: String(localized: "背包剩余 %d 格"), remainingCapacity))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(remainingCapacity == 0 ? ApocalypseTheme.danger : ApocalypseTheme.textPrimary)

                GeometryReader { geo in
                    let total = Double(inventoryManager.backpackCapacity)
                    let used = Double(inventoryManager.totalItemCount)
                    let pct = total > 0 ? min(used / total, 1.0) : 0
                    let color: Color = pct > 0.9 ? ApocalypseTheme.danger : (pct > 0.7 ? ApocalypseTheme.warning : ApocalypseTheme.success)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(ApocalypseTheme.textMuted.opacity(0.2)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * pct, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text("\(inventoryManager.totalItemCount)/\(inventoryManager.backpackCapacity)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground))
        .padding(.horizontal, 20)
    }
}

// MARK: - 可勾选物品行

struct SelectableAIItemRow: View {
    let item: AIGeneratedItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                // 勾选框
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                    .padding(.top, 11)

                // 物品内容
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(rarityColor(item.rarity).opacity(isSelected ? 0.2 : 0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: categoryIcon(item.category))
                                .font(.system(size: 18))
                                .foregroundColor(rarityColor(item.rarity).opacity(isSelected ? 1 : 0.4))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSelected ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                            Text(rarityText(item.rarity))
                                .font(.system(size: 12))
                                .foregroundColor(rarityColor(item.rarity).opacity(isSelected ? 1 : 0.5))
                        }

                        Spacer()

                        Text("x\(item.quantity)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }

                    if !item.story.isEmpty {
                        let preview = item.story.count > 60 ? String(item.story.prefix(60)) + "..." : item.story
                        Text(preview)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? ApocalypseTheme.textSecondary : ApocalypseTheme.textMuted.opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? ApocalypseTheme.success.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return ApocalypseTheme.textMuted
        }
    }

    private func rarityText(_ rarity: String) -> String {
        switch rarity {
        case "common": return String(localized: "普通")
        case "uncommon": return String(localized: "优秀")
        case "rare": return String(localized: "稀有")
        case "epic": return String(localized: "史诗")
        case "legendary": return String(localized: "传说")
        default: return String(localized: "未知")
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.fill"
        case "weapon": return "bolt.fill"
        case "clothing": return "tshirt.fill"
        default: return "archivebox.fill"
        }
    }
}

// MARK: - AI物品行组件

struct AIItemRow: View {
    let item: AIGeneratedItem
    @State private var showFullStory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 图标和名称
                ZStack {
                    Circle()
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(rarityColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(rarityText)
                        .font(.system(size: 12))
                        .foregroundColor(rarityColor)
                }

                Spacer()

                Text("x\(item.quantity)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 背景故事（可展开）
            if !item.story.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showFullStory ? item.story : shortenedStory)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(showFullStory ? nil : 2)

                    if item.story.count > 50 {
                        Button {
                            withAnimation {
                                showFullStory.toggle()
                            }
                        } label: {
                            Text(showFullStory ? LocalizedStringKey("收起") : LocalizedStringKey("展开"))
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private var shortenedStory: String {
        item.story.count > 50 ? String(item.story.prefix(50)) + "..." : item.story
    }

    private var rarityColor: Color {
        switch item.rarity {
        case "common":
            return .gray
        case "uncommon":
            return .green
        case "rare":
            return .blue
        case "epic":
            return .purple
        case "legendary":
            return .orange
        default:
            return ApocalypseTheme.textMuted
        }
    }

    private var rarityText: String {
        switch item.rarity {
        case "common":
            return String(localized: "普通")
        case "uncommon":
            return String(localized: "优秀")
        case "rare":
            return String(localized: "稀有")
        case "epic":
            return String(localized: "史诗")
        case "legendary":
            return String(localized: "传说")
        default:
            return String(localized: "未知")
        }
    }

    private var categoryIcon: String {
        switch item.category {
        case "water":
            return "drop.fill"
        case "food":
            return "fork.knife"
        case "medical":
            return "cross.case.fill"
        case "material":
            return "cube.fill"
        case "tool":
            return "wrench.fill"
        case "weapon":
            return "bolt.fill"
        case "clothing":
            return "tshirt.fill"
        default:
            return "archivebox.fill"
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
                        Text(definition.rarity.displayName)
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

// MARK: - ScavengeResultSheet（用于 POIDetailView 的 sheet 展示）

struct ScavengeResultSheet: View {
    let result: ScavengeResult
    @ObservedObject private var explorationManager = ExplorationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScavengeResultView(
                result: result,
                onConfirm: { selectedIds in
                    Task {
                        await explorationManager.confirmScavengeResult(selectedIds: selectedIds)
                        dismiss()
                    }
                },
                onDiscard: {
                    explorationManager.discardScavengeResult()
                    dismiss()
                }
            )
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
                    AIGeneratedItem(
                        name: "生锈的矿泉水",
                        story: "瓶身已经生锈,但里面的水依然清澈。这可能是废墟中最珍贵的东西了。",
                        category: "water",
                        rarity: "common",
                        quantity: 2
                    ),
                    AIGeneratedItem(
                        name: "过期罐头",
                        story: "虽然已经过期,但密封还算完好。在末日中,过期食品也是奢侈品。",
                        category: "food",
                        rarity: "uncommon",
                        quantity: 1
                    ),
                    AIGeneratedItem(
                        name: "医用绷带",
                        story: "一包保存完好的医用绷带,在这个缺医少药的时代,它可以救命。",
                        category: "medical",
                        rarity: "rare",
                        quantity: 3
                    )
                ],
                sessionId: "test"
            ),
            onConfirm: { _ in },
            onDiscard: {}
        )
    }
}
