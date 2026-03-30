//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道 Sheet
//

import SwiftUI
import Auth

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedType: ChannelType = .public
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    @ObservedObject private var commManager = CommunicationManager.shared
    private var isValidName: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    /// 玩家当前有效领地数量
    private var territoryCount: Int {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return 0 }
        return TerritoryManager.shared.territories.filter {
            $0.isActive == true && $0.userId.lowercased() == userId
        }.count
    }

    /// 频道类型所需最少领地数
    private func requiredTerritoryCount(for type: ChannelType) -> Int {
        switch type {
        case .walkie:    return 1
        case .camp:      return 10
        case .satellite: return 20
        default:         return 0
        }
    }

    /// 频道类型对应的必需设备
    private func requiredDevice(for type: ChannelType) -> DeviceType? {
        switch type {
        case .public:    return nil
        case .walkie:    return .walkieTalkie
        case .camp:      return .campRadio
        case .satellite: return .satellite
        default:         return nil
        }
    }

    /// 单项设备条件是否满足
    private func isDeviceUnlocked(for type: ChannelType) -> Bool {
        let required = requiredDevice(for: type)
        guard let required else { return true }
        return commManager.devices.first(where: { $0.deviceType == required })?.isUnlocked ?? false
    }

    /// 单项领地条件是否满足
    private func isTerritoryMet(for type: ChannelType) -> Bool {
        territoryCount >= requiredTerritoryCount(for: type)
    }

    /// 级联检查：该频道及其前置频道的所有条件是否全部满足
    private func isFullyUnlocked(for type: ChannelType) -> Bool {
        switch type {
        case .public:
            return true
        case .walkie:
            return isTerritoryMet(for: .walkie) && isDeviceUnlocked(for: .walkie)
        case .camp:
            return isFullyUnlocked(for: .walkie)
                && isTerritoryMet(for: .camp) && isDeviceUnlocked(for: .camp)
        case .satellite:
            return isFullyUnlocked(for: .camp)
                && isTerritoryMet(for: .satellite) && isDeviceUnlocked(for: .satellite)
        default:
            return true
        }
    }

    /// 当前选中频道类型的所有解锁条件是否满足
    private var isRequiredDeviceUnlocked: Bool {
        isFullyUnlocked(for: selectedType)
    }

    /// 未满足条件时的提示文字（按优先级显示最前置的未满足条件）
    private var deviceUnlockHint: String? {
        var hints: [String] = []

        // 对讲频道前置条件
        if selectedType == .camp || selectedType == .satellite {
            if !isFullyUnlocked(for: .walkie) {
                hints.append(String(localized: "需要先解锁对讲频道"))
            }
        }

        // 营地频道前置条件
        if selectedType == .satellite {
            if isFullyUnlocked(for: .walkie) && !isFullyUnlocked(for: .camp) {
                hints.append(String(localized: "需要先解锁营地频道"))
            }
        }

        // 当前频道自身条件（仅在前置已满足时显示）
        let prerequisiteMet: Bool = {
            switch selectedType {
            case .camp:      return isFullyUnlocked(for: .walkie)
            case .satellite: return isFullyUnlocked(for: .camp)
            default:         return true
            }
        }()

        if prerequisiteMet {
            if !isTerritoryMet(for: selectedType) {
                let needed = requiredTerritoryCount(for: selectedType)
                hints.append(String(format: String(localized: "需要圈地 %d 块（当前 %d 块）"), needed, territoryCount))
            }
            if !isDeviceUnlocked(for: selectedType) {
                switch selectedType {
                case .walkie:
                    hints.append(String(localized: "需要建造「瞭望台」解锁对讲机"))
                case .camp:
                    hints.append(String(localized: "需要建造「营地电台」解锁营地电台设备"))
                case .satellite:
                    hints.append(String(localized: "需要建造「领主指挥所」解锁卫星电话"))
                default:
                    break
                }
            }
        }

        return hints.isEmpty ? nil : hints.joined(separator: "\n")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    channelTypeSection

                    // 频道名称
                    channelNameSection

                    // 频道描述
                    channelDescriptionSection

                    // 错误提示
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // 创建按钮
                    createButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Channel Type Section

    private var channelTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ChannelType.creatableTypes) { type in
                    channelTypeCard(type)
                }
            }
        }
    }

    private func channelTypeCard(_ type: ChannelType) -> some View {
        let unlocked = isFullyUnlocked(for: type)

        return Button(action: { selectedType = type }) {
            VStack(spacing: 8) {
                // 图标
                ZStack {
                    Circle()
                        .fill(type.color.opacity(selectedType == type ? 0.3 : 0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(unlocked ? type.color : ApocalypseTheme.textMuted)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .offset(x: 16, y: 16)
                    }
                }

                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(unlocked ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)

                // 解锁需求列表（公共频道不显示）
                if type != .public {
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.2))
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(requirementItems(for: type), id: \.label) { item in
                            HStack(spacing: 5) {
                                Image(systemName: item.met ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(item.met ? .green : ApocalypseTheme.textMuted)
                                Text(item.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(item.met ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedType == type ? type.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(unlocked ? 1.0 : 0.6)
        }
    }

    /// 每个频道类型的三条解锁需求
    private func requirementItems(for type: ChannelType) -> [(label: String, met: Bool)] {
        switch type {
        case .walkie:
            return [
                (String(localized: "圈地 ≥ 1 块（当前\(territoryCount)块）"),
                 isTerritoryMet(for: .walkie)),
                (String(localized: "建造「瞭望台」解锁对讲机"),
                 isDeviceUnlocked(for: .walkie)),
                (String(localized: "无前置频道要求"), true)
            ]
        case .camp:
            return [
                (String(localized: "已解锁对讲频道"),
                 isFullyUnlocked(for: .walkie)),
                (String(localized: "圈地 ≥ 10 块（当前\(territoryCount)块）"),
                 isTerritoryMet(for: .camp)),
                (String(localized: "建造「营地电台」解锁营地电台"),
                 isDeviceUnlocked(for: .camp))
            ]
        case .satellite:
            return [
                (String(localized: "已解锁营地频道"),
                 isFullyUnlocked(for: .camp)),
                (String(localized: "圈地 ≥ 20 块（当前\(territoryCount)块）"),
                 isTerritoryMet(for: .satellite)),
                (String(localized: "建造「领主指挥所」解锁卫星电话"),
                 isDeviceUnlocked(for: .satellite))
            ]
        default:
            return []
        }
    }

    // MARK: - Channel Name Section

    private var channelNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(
                        channelName.count > 50 ? ApocalypseTheme.danger :
                        channelName.count < 2 ? ApocalypseTheme.textSecondary :
                        ApocalypseTheme.success
                    )
            }

            TextField("输入频道名称", text: $channelName)
                .textFieldStyle(.plain)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            channelName.isEmpty ? Color.clear :
                            isValidName ? ApocalypseTheme.success.opacity(0.5) :
                            ApocalypseTheme.danger.opacity(0.5),
                            lineWidth: 1
                        )
                )

            if !channelName.isEmpty && !isValidName {
                Text("频道名称需要 2-50 个字符")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    // MARK: - Channel Description Section

    private var channelDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道描述")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            TextEditor(text: $channelDescription)
                .frame(minHeight: 80)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)

            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.danger)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 8) {
            if let hint = deviceUnlockHint {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text(hint)
                        .font(.subheadline)
                }
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 4)
            }

            Button(action: createChannel) {
                HStack {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.textPrimary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isRequiredDeviceUnlocked ? "plus.circle.fill" : "lock.fill")
                    }
                    Text(isCreating ? String(localized: "创建中...") : String(localized: "创建频道"))
                }
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isValidName && !isCreating && isRequiredDeviceUnlocked ?
                    ApocalypseTheme.primary :
                    ApocalypseTheme.primary.opacity(0.3)
                )
                .cornerRadius(12)
            }
            .disabled(!isValidName || isCreating || !isRequiredDeviceUnlocked)
            .padding(.top, 4)
        }
    }

    // MARK: - Methods

    private func createChannel() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = String(localized: "用户未登录")
            return
        }

        guard isValidName else {
            errorMessage = String(localized: "请输入有效的频道名称")
            return
        }

        guard isRequiredDeviceUnlocked else {
            errorMessage = deviceUnlockHint
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await communicationManager.createChannel(
                    creatorId: userId,
                    channelType: selectedType,
                    name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: channelDescription.isEmpty ? nil : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager.shared)
}
