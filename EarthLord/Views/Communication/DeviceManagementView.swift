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
    @EnvironmentObject var authManager: AuthManager
    @State private var showUnlockAlert = false
    @State private var selectedDeviceForUnlock: DeviceType?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题
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

                // 当前设备卡片
                if let current = communicationManager.currentDevice {
                    currentDeviceCard(current)
                }

                // 设备列表
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
        .alert("设备未解锁", isPresented: $showUnlockAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            if let device = selectedDeviceForUnlock {
                Text(device.unlockRequirement)
            }
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
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.primary, lineWidth: 2)
        )
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
            showUnlockAlert = true
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

#Preview {
    DeviceManagementView()
        .environmentObject(AuthManager.shared)
}
