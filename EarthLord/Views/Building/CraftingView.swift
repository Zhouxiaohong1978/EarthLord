// CraftingView.swift
// EarthLord — 工作台合成界面

import SwiftUI

struct CraftingView: View {
    let buildingLevel: Int
    let buildingTemplateId: String

    @StateObject private var craftingManager = CraftingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var selectedRecipe: CraftingRecipe?
    @State private var showConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var collectToWarehouse = false

    private let lm = LanguageManager.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    slotHeader
                    if !craftingManager.activeJobs.isEmpty {
                        activeJobsSection
                    }
                    recipesSection
                }
                .padding(16)
            }

            // 确认弹窗 overlay（避免 sheet 套 sheet 背景问题）
            if showConfirm, let recipe = selectedRecipe {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { showConfirm = false }

                VStack {
                    Spacer()
                    CraftingConfirmSheet(
                        recipe: recipe,
                        buildingLevel: buildingLevel,
                        onConfirm: { toWarehouse in
                            showConfirm = false
                            Task { await startCrafting(recipe: recipe, toWarehouse: toWarehouse) }
                        },
                        onCancel: { showConfirm = false }
                    )
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.25), value: showConfirm)
            }
        }
        .navigationTitle({
            switch buildingTemplateId {
            case "food_factory":      return String(localized: "食品加工")
            case "equipment_forge":   return String(localized: "装备强化")
            default:                  return String(localized: "工作台合成")
            }
        }())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { CraftingManager.shared.reloadForCurrentUser() }
        .alert(errorMessage ?? "", isPresented: $showError) {
            Button(String(localized: "确定"), role: .cancel) {}
        }
    }

    // MARK: - Slot Header

    private var slotHeader: some View {
        HStack {
            Image(systemName: "hammer.fill")
                .foregroundColor(ApocalypseTheme.primary)
            Text("合成槽位")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            let used = craftingManager.activeJobCount
            let max = craftingManager.maxSlots(buildingLevel: buildingLevel)
            Text("\(used)/\(max)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(used >= max ? ApocalypseTheme.danger : ApocalypseTheme.success)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Active Jobs

    private var activeJobsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("进行中")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            ForEach(craftingManager.activeJobs) { job in
                CraftingJobRow(job: job, onCollect: { toWarehouse in
                    Task {
                        do {
                            try await craftingManager.collectJob(jobId: job.id, toWarehouse: toWarehouse)
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                })
            }
        }
    }

    // MARK: - Recipes

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("可合成配方")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            ForEach(craftingManager.recipes(for: buildingTemplateId)) { recipe in
                RecipeRow(recipe: recipe) {
                    selectedRecipe = recipe
                    showConfirm = true
                }
            }
        }
    }

    // MARK: - Actions

    private func startCrafting(recipe: CraftingRecipe, toWarehouse: Bool) async {
        do {
            try await craftingManager.startCrafting(recipe: recipe, buildingLevel: buildingLevel)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - CraftingJobRow

struct CraftingJobRow: View {
    let job: CraftingJob
    let onCollect: (Bool) -> Void

    @State private var progress: Double = 0
    @State private var remaining: String = ""
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemName(for: job.outputItemId))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("×\(job.outputQuantity)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                Spacer()
                if job.collected {
                    Text("已领取")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.success)
                } else if job.isComplete {
                    HStack(spacing: 8) {
                        collectButton(toWarehouse: false)
                        collectButton(toWarehouse: true)
                    }
                } else {
                    Text(remaining)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            if !job.isComplete {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ApocalypseTheme.primary)
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private func collectButton(toWarehouse: Bool) -> some View {
        Button {
            onCollect(toWarehouse)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: toWarehouse ? "archivebox.fill" : "backpack.fill")
                    .font(.system(size: 11))
                Text(toWarehouse ? "入仓" : "入包")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(toWarehouse ? ApocalypseTheme.info : ApocalypseTheme.success)
            .cornerRadius(8)
        }
    }

    private func refresh() {
        progress = job.progress
        remaining = job.remainingFormatted
    }

    private func itemName(for itemId: String) -> String {
        LanguageManager.shared.localizedString(for: "item.\(itemId)")
            .ifEmpty(then: LanguageManager.shared.localizedString(for: itemId))
    }
}

// MARK: - RecipeRow

struct RecipeRow: View {
    let recipe: CraftingRecipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 输出物
                VStack(spacing: 4) {
                    Image(systemName: outputIcon(for: recipe.outputItemId))
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("×\(recipe.outputQuantity)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .frame(width: 44)

                // 箭头
                Image(systemName: "arrow.left")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                // 所需材料
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemDisplayName(recipe.outputItemId))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(Array(recipe.inputs.sorted(by: { $0.key < $1.key })), id: \.key) { itemId, qty in
                            HStack(spacing: 3) {
                                Text(itemDisplayName(itemId))
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Text("×\(qty)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(hasEnough(itemId: itemId, qty: qty) ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
                            }
                        }
                    }
                }

                Spacer()

                // 耗时
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(recipe.durationFormatted)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(14)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func itemDisplayName(_ itemId: String) -> String {
        let key = "item.\(itemId)"
        let localized = LanguageManager.shared.localizedString(for: key)
        if localized != key { return localized }
        return LanguageManager.shared.localizedString(for: itemId)
    }

    private func outputIcon(for itemId: String) -> String {
        switch itemId {
        case "bandage":     return "cross.fill"
        case "rope":        return "link"
        case "nails":       return "pin.fill"
        case "tool":        return "wrench.fill"
        case "toolbox":     return "briefcase.fill"
        case "bread":           return "birthday.cake.fill"
        case "hardtack":        return "square.fill"
        case "canned_food":     return "cylinder.fill"
        case "juice":           return "drop.fill"
        case "equipment_epic":  return "shield.lefthalf.filled"
        case "equipment_rare":  return "shield.fill"
        default:                return "cube.fill"
        }
    }

    private func hasEnough(itemId: String, qty: Int) -> Bool {
        let inBackpack  = InventoryManager.shared.items.filter { $0.itemId == itemId && $0.customName == nil }.reduce(0) { $0 + $1.quantity }
        let inWarehouse = WarehouseManager.shared.items.filter { $0.itemId == itemId && $0.customName == nil }.reduce(0) { $0 + $1.quantity }
        return inBackpack + inWarehouse >= qty
    }
}

// MARK: - CraftingConfirmSheet

struct CraftingConfirmSheet: View {
    let recipe: CraftingRecipe
    let buildingLevel: Int
    let onConfirm: (Bool) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // 标题
            VStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 32))
                    .foregroundColor(ApocalypseTheme.primary)
                Text("开始合成")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("耗时 \(recipe.durationFormatted)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.bottom, 20)

            // 配方详情
            VStack(spacing: 0) {
                ForEach(Array(recipe.inputs.sorted(by: { $0.key < $1.key })), id: \.key) { itemId, qty in
                    HStack {
                        Text(localizedItemName(itemId))
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                        Text("×\(qty)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    Divider().background(Color.white.opacity(0.06))
                }
                HStack {
                    Text("产出")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    Text("\(localizedItemName(recipe.outputItemId)) ×\(recipe.outputQuantity)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // 按钮
            VStack(spacing: 10) {
                Button { onConfirm(false) } label: {
                    Label("完成后存入背包", systemImage: "backpack.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                Button { onConfirm(true) } label: {
                    Label("完成后存入仓库", systemImage: "archivebox.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                }
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func localizedItemName(_ itemId: String) -> String {
        let key = "item.\(itemId)"
        let localized = LanguageManager.shared.localizedString(for: key)
        if localized != key { return localized }
        return LanguageManager.shared.localizedString(for: itemId)
    }
}

// MARK: - String Extension

private extension String {
    func ifEmpty(then fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
