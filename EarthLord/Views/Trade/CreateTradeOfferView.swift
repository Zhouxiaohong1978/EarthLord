//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布挂单页面
//  选择出售/求购物品，设置有效期，发布交易挂单
//

import SwiftUI
import Auth

struct CreateTradeOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    // MARK: - 状态

    @State private var offeringItems: [TradeItem] = []
    @State private var requestingItems: [TradeItem] = []
    @State private var selectedDuration: Int = 24  // 小时
    @State private var message: String = ""

    @State private var showOfferingPicker = false
    @State private var showRequestingPicker = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false

    /// 有效期选项
    private let durationOptions = [6, 12, 24, 48, 72]

    /// 是否可以发布
    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 出售物品区域
                        offeringSection

                        // 交换图标
                        exchangeIcon

                        // 求购物品区域
                        requestingSection

                        // 有效期选择
                        durationSection

                        // 留言输入
                        messageSection

                        // 预览卡片
                        if canSubmit {
                            previewSection
                        }

                        // 发布按钮
                        submitButton
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showOfferingPicker) {
                ItemPickerSheet(mode: .fromInventory) { items in
                    offeringItems = items
                }
            }
            .sheet(isPresented: $showRequestingPicker) {
                ItemPickerSheet(mode: .fromAllItems) { items in
                    requestingItems = items
                }
            }
            .alert("发布失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("发布成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("挂单已发布，可在「我的挂单」中查看")
            }
        }
    }

    // MARK: - 出售物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("出售物品", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Text("从库存选择")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if offeringItems.isEmpty {
                // 空状态
                Button {
                    showOfferingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))

                        Text("添加出售物品")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.success)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.success.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ApocalypseTheme.success.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                    )
                }
            } else {
                // 已选物品列表
                VStack(spacing: 8) {
                    ForEach(offeringItems) { item in
                        TradeItemRow(
                            item: item,
                            showDeleteButton: true,
                            onDelete: {
                                offeringItems.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    // 添加更多按钮
                    Button {
                        showOfferingPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("添加更多")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.vertical, 8)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.cardBackground)
                )
            }
        }
    }

    // MARK: - 交换图标

    private var exchangeIcon: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            Spacer()
        }
    }

    // MARK: - 求购物品区域

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("求购物品", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Spacer()

                Text("从物品库选择")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if requestingItems.isEmpty {
                // 空状态
                Button {
                    showRequestingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))

                        Text("添加求购物品")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.info.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ApocalypseTheme.info.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                    )
                }
            } else {
                // 已选物品列表
                VStack(spacing: 8) {
                    ForEach(requestingItems) { item in
                        TradeItemRow(
                            item: item,
                            showDeleteButton: true,
                            onDelete: {
                                requestingItems.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    // 添加更多按钮
                    Button {
                        showRequestingPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("添加更多")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(ApocalypseTheme.info)
                        .padding(.vertical, 8)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.cardBackground)
                )
            }
        }
    }

    // MARK: - 有效期选择

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("有效期", systemImage: "clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(durationOptions, id: \.self) { hours in
                        durationButton(hours)
                    }
                }
            }
        }
    }

    private func durationButton(_ hours: Int) -> some View {
        let isSelected = selectedDuration == hours

        return Button {
            selectedDuration = hours
        } label: {
            Text("\(hours)小时")
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - 留言输入

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("留言", systemImage: "text.bubble")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("可选")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            TextField("给其他玩家的留言...", text: $message, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - 预览卡片

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            TradeOfferCard(
                offer: TradeOffer(
                    ownerId: AuthManager.shared.currentUser?.id ?? UUID(),
                    ownerUsername: AuthManager.shared.currentUser?.email ?? "我",
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    message: message.isEmpty ? nil : message,
                    expiresAt: Date().addingTimeInterval(Double(selectedDuration) * 3600)
                )
            )
        }
    }

    // MARK: - 发布按钮

    private var submitButton: some View {
        Button {
            submitOffer()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }

                Text(isSubmitting ? "发布中..." : "发布挂单")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canSubmit)
    }

    // MARK: - 提交挂单

    private func submitOffer() {
        guard canSubmit else { return }

        isSubmitting = true

        Task {
            do {
                _ = try await tradeManager.createOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    message: message.isEmpty ? nil : message,
                    durationHours: selectedDuration
                )

                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    CreateTradeOfferView()
}
