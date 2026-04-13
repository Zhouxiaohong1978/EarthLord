//
//  DeviceManagementView.swift
//  EarthLord
//
//  设备管理页面 - 查看和切换通讯设备
//

import SwiftUI
import Supabase

struct DeviceManagementView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDeviceForUnlock: DeviceType?
    @State private var showUpgradeConfirm = false
    @State private var isUpgrading = false
    @State private var upgradeError: String?

    /// 背包里的设备升级令数量
    private var upgradeTokenCount: Int {
        inventoryManager.items
            .filter { $0.itemId == "device_upgrade_token" }
            .reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设备管理")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("选择通讯设备，不同设备有不同覆盖范围")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let current = communicationManager.currentDevice {
                    currentDeviceCard(current)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("所有设备")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(DeviceType.allCases, id: \.self) { deviceType in
                        deviceCard(deviceType)
                    }
                }
            }
            .padding(16)
        }
        .background(ApocalypseTheme.background)
        .sheet(item: $selectedDeviceForUnlock) { device in
            DeviceUnlockSheet(deviceType: device)
                .environmentObject(authManager)
        }
    }

    // MARK: - 当前设备大卡片

    private func currentDeviceCard(_ device: CommunicationDevice) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: device.deviceType.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceType.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("覆盖范围: \(device.deviceType.rangeText)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.canSend ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(device.deviceType.canSend ? "可发送" : "仅接收")
                        .font(.caption)
                }
                .foregroundColor(device.deviceType.canSend ? .green : .orange)
            }

            Spacer()

            // 升级令按钮（背包里有令牌且当前设备不是卫星时显示）
            if upgradeTokenCount > 0 && device.deviceType != .satellite {
                Button {
                    showUpgradeConfirm = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                        Text("升级令 ×\(upgradeTokenCount)")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                }
                .confirmationDialog(
                    "使用设备升级令",
                    isPresented: $showUpgradeConfirm,
                    titleVisibility: .visible
                ) {
                    Button("确认升级（消耗 1 枚升级令）") {
                        Task { await useUpgradeToken() }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("将当前设备「\(device.deviceType.displayName)」升级为下一型号，需消耗 1 枚设备升级令。")
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(upgradeTokenCount > 0 && device.deviceType != .satellite
                        ? Color.cyan : ApocalypseTheme.primary, lineWidth: 2)
        )
        .overlay(alignment: .bottom) {
            if let err = upgradeError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.bottom, 8)
            }
        }
    }

    /// 使用升级令升级当前设备型号
    private func useUpgradeToken() async {
        guard let userId = authManager.currentUser?.id else { return }
        isUpgrading = true
        upgradeError = nil
        defer { isUpgrading = false }

        do {
            // 1. 升级设备型号
            try await communicationManager.upgradeCurrentDeviceType(userId: userId)

            // 2. 消耗1枚升级令
            if let token = inventoryManager.items.first(where: { $0.itemId == "device_upgrade_token" }) {
                try await inventoryManager.useItem(inventoryId: token.id, quantity: 1)
            }
        } catch {
            upgradeError = error.localizedDescription
        }
    }

    // MARK: - 设备列表卡片

    private func deviceCard(_ deviceType: DeviceType) -> some View {
        let device = communicationManager.devices.first(where: { $0.deviceType == deviceType })
        let isUnlocked = device?.isUnlocked ?? false
        let isCurrent = device?.isCurrent ?? false

        return Button(action: { handleTap(deviceType, isUnlocked, isCurrent) }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? ApocalypseTheme.primary.opacity(0.15) : ApocalypseTheme.textSecondary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: deviceType.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(isUnlocked ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(deviceType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isUnlocked ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                        if isCurrent {
                            Text("当前")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(4)
                        }
                    }

                    Text(deviceType.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else if !isCurrent {
                    Text("切换")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .opacity(isUnlocked ? 1.0 : 0.6)
        }
        .disabled(isCurrent)
    }

    // MARK: - 点击处理

    private func handleTap(_ deviceType: DeviceType, _ isUnlocked: Bool, _ isCurrent: Bool) {
        if isCurrent { return }

        if !isUnlocked {
            selectedDeviceForUnlock = deviceType
            return
        }

        guard let userId = authManager.currentUser?.id else { return }

        Task {
            do {
                try await communicationManager.switchDevice(userId: userId, to: deviceType)
            } catch {
                print("切换设备失败: \(error)")
            }
        }
    }
}

// MARK: - 解锁要求弹窗

struct DeviceUnlockSheet: View {
    let deviceType: DeviceType
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @StateObject private var buildingManager = BuildingManager.shared

    @State private var isUnlocking = false
    @State private var unlockError: String?

    // 需要的建筑 templateId + 名称
    private var requiredBuildingId: String? {
        switch deviceType {
        case .radio:        return nil
        case .walkieTalkie: return "watchtower"
        case .campRadio:    return "radio_station"
        case .satellite:    return "lord_command"
        }
    }

    private var requiredBuildingName: String {
        switch deviceType {
        case .radio:        return ""
        case .walkieTalkie: return String(localized: "瞭望台")
        case .campRadio:    return String(localized: "营地电台")
        case .satellite:    return String(localized: "领主指挥所")
        }
    }

    // 前置设备要求（需已解锁）
    private var prerequisiteDevice: DeviceType? {
        switch deviceType {
        case .radio, .walkieTalkie: return nil
        case .campRadio:            return .walkieTalkie
        case .satellite:            return .campRadio
        }
    }

    // 领地数量要求
    private var requiredTerritoryCount: Int {
        switch deviceType {
        case .radio:        return 0
        case .walkieTalkie: return 1
        case .campRadio:    return 10
        case .satellite:    return 20
        }
    }

    private var myTerritoryCount: Int {
        let myId = authManager.currentUser?.id.uuidString.lowercased() ?? ""
        return TerritoryManager.shared.territories.filter {
            $0.isActive == true && $0.userId.lowercased() == myId
        }.count
    }

    private var territoryMet: Bool {
        myTerritoryCount >= requiredTerritoryCount
    }

    private var buildingMet: Bool {
        guard let bid = requiredBuildingId else { return true }
        return buildingManager.playerBuildings.contains {
            $0.templateId == bid && $0.status == .active
        }
    }

    private var prerequisiteMet: Bool {
        guard let pre = prerequisiteDevice else { return true }
        return communicationManager.isDeviceUnlocked(pre)
    }

    private var allMet: Bool { territoryMet && buildingMet && prerequisiteMet }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 设备图标 + 名称
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.primary.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: deviceType.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        Text(deviceType.displayName)
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(deviceType.description)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // 解锁要求
                    VStack(spacing: 0) {
                        sectionHeader(String(localized: "解锁要求"))

                        VStack(spacing: 1) {
                            // 前置设备要求
                            if let pre = prerequisiteDevice {
                                requirementRow(
                                    icon: pre.iconName,
                                    title: String(localized: "前置设备"),
                                    detail: String(format: String(localized: "需先解锁 %@"), pre.displayName),
                                    met: prerequisiteMet
                                )
                            }

                            // 领地需求
                            requirementRow(
                                icon: "flag.fill",
                                title: String(localized: "领地需求"),
                                detail: String(format: String(localized: "至少拥有 %lld 块领地（当前 %lld 块）"), requiredTerritoryCount, myTerritoryCount),
                                met: territoryMet
                            )

                            // 建造要求
                            if let _ = requiredBuildingId {
                                requirementRow(
                                    icon: "building.2.fill",
                                    title: String(localized: "建造要求"),
                                    detail: String(format: String(localized: "建造 %@"), requiredBuildingName),
                                    met: buildingMet
                                )
                            }
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    // 覆盖范围说明
                    HStack(spacing: 8) {
                        Image(systemName: "wave.3.right")
                            .foregroundColor(ApocalypseTheme.info)
                        Text(String(format: String(localized: "解锁后覆盖范围：%@"), deviceType.rangeText))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(10)

                    if let err = unlockError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // 升级按钮
                    Button(action: unlock) {
                        HStack(spacing: 8) {
                            if isUnlocking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: allMet ? "lock.open.fill" : "lock.fill")
                            }
                            Text(allMet ? "升级设备" : "条件未满足")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(allMet ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        )
                    }
                    .disabled(!allMet || isUnlocking)
                }
                .padding(20)
            }
            .navigationTitle("设备升级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote).fontWeight(.semibold)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    private func requirementRow(icon: String, title: String, detail: String, met: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(met ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(met ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(14)
    }

    private func unlock() {
        guard let userId = authManager.currentUser?.id else { return }
        isUnlocking = true
        unlockError = nil
        Task {
            do {
                try await communicationManager.unlockDevice(userId: userId, deviceType: deviceType)
                dismiss()
            } catch {
                unlockError = String(localized: "升级失败，请稍后重试")
            }
            isUnlocking = false
        }
    }
}

#Preview {
    DeviceManagementView()
        .environmentObject(AuthManager.shared)
}
