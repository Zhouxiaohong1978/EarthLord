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
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var commManager = CommunicationManager.shared

    @State private var selectedType: ChannelType = .walkie
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isPublic = false
    @State private var requiresApproval = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showUnlockAlert = false

    private var isValidName: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var canCreate: Bool {
        isValidName && !isCreating
    }

    private var unlockAlertMessage: String {
        var lines: [String] = []
        if !isDeviceUnlocked(for: selectedType) {
            switch selectedType {
            case .walkie:    lines.append(String(localized: "需要解锁对讲机、营地电台或卫星设备"))
            case .camp:      lines.append(String(localized: "需要建造「营地电台」或解锁卫星设备"))
            case .satellite: lines.append(String(localized: "需要建造「领主指挥所」解锁卫星设备"))
            default: break
            }
        } else if !isTokenUnlocked(for: selectedType) && !isTerritoryMet(for: selectedType) {
            let needed = requiredTerritoryCount(for: selectedType)
            lines.append(String(format: String(localized: "需要圈地 %d 块（当前 %d 块）"), needed, territoryCount))
        }
        return lines.joined(separator: "\n")
    }

    /// 玩家当前有效领地数量
    private var territoryCount: Int {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else { return 0 }
        return TerritoryManager.shared.territories.filter {
            $0.isActive == true && $0.userId.lowercased() == userId
        }.count
    }

    private func requiredTerritoryCount(for type: ChannelType) -> Int {
        switch type {
        case .walkie:    return 1
        case .camp:      return 10
        case .satellite: return 20
        default:         return 0
        }
    }

    private func isDeviceUnlocked(for type: ChannelType) -> Bool {
        let capable: [DeviceType]
        switch type {
        case .walkie:    capable = [.walkieTalkie, .campRadio, .satellite]
        case .camp:      capable = [.campRadio, .satellite]
        case .satellite: capable = [.satellite]
        default:         return true
        }
        return capable.contains { dt in
            commManager.devices.first(where: { $0.deviceType == dt })?.isUnlocked ?? false
        }
    }

    /// 该等级或更高等级中，是否有通过升级令解锁的设备（付费路线，无领地门槛）
    private func isTokenUnlocked(for type: ChannelType) -> Bool {
        let capable: [DeviceType]
        switch type {
        case .walkie:    capable = [.walkieTalkie, .campRadio, .satellite]
        case .camp:      capable = [.campRadio, .satellite]
        case .satellite: capable = [.satellite]
        default:         return true
        }
        return capable.contains { dt in
            commManager.devices.first(where: { $0.deviceType == dt })?.isTokenUnlocked == true
        }
    }

    private func isTerritoryMet(for type: ChannelType) -> Bool {
        territoryCount >= requiredTerritoryCount(for: type)
    }

    private func isFullyUnlocked(for type: ChannelType) -> Bool {
        guard isDeviceUnlocked(for: type) else { return false }
        // 升级令解锁（付费）：无领地门槛
        if isTokenUnlocked(for: type) { return true }
        // 建筑解锁（免费）：需满足领地数量
        return isTerritoryMet(for: type)
    }

    private func channelTypeColor(_ type: ChannelType) -> Color {
        switch type {
        case .walkie:    return Color(red: 0.22, green: 0.78, blue: 0.45)  // 绿色：近距离
        case .camp:      return Color(red: 0.20, green: 0.60, blue: 1.00)  // 蓝色：中距离
        case .satellite: return Color(red: 0.75, green: 0.35, blue: 1.00)  // 紫色：远距离
        default:         return .gray
        }
    }

    private func channelTypeIcon(_ type: ChannelType) -> String {
        switch type {
        case .walkie:    return "antenna.radiowaves.left.and.right"
        case .camp:      return "dot.radiowaves.left.and.right"
        case .satellite: return "iphone.radiowaves.left.and.right"
        default:         return "wifi"
        }
    }

    private func channelTypeName(_ type: ChannelType) -> String {
        switch type {
        case .walkie:    return String(localized: "对讲机频道")
        case .camp:      return String(localized: "营地电台")
        case .satellite: return String(localized: "手机频道")
        default:         return type.displayName
        }
    }

    private func channelTypeRange(_ type: ChannelType) -> String {
        switch type {
        case .walkie:    return "3 km"
        case .camp:      return "30 km"
        case .satellite: return "100 km+"
        default:         return ""
        }
    }

    @ViewBuilder
    private func channelTypeCard(_ type: ChannelType) -> some View {
        let isSelected = selectedType == type
        let color = channelTypeColor(type)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedType = type
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(isSelected ? 0.25 : 0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: channelTypeIcon(type))
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channelTypeName(type))
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? color : ApocalypseTheme.textPrimary)
                    Text(String(format: String(localized: "覆盖范围：%@"), channelTypeRange(type)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(isSelected ? 0.12 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: 频道名称
                Section(header: Text(String(localized: "频道名称"))) {
                    TextField(String(localized: "输入频道名称（2-50字）"), text: $channelName)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.vertical, 4)
                }

                // MARK: 频道类型
                Section(header: Text(String(localized: "频道类型"))) {
                    VStack(spacing: 10) {
                        ForEach([ChannelType.walkie, .camp, .satellite], id: \.self) { type in
                            channelTypeCard(type)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: 频道描述
                Section(header: Text(String(localized: "频道描述（可选）"))) {
                    TextEditor(text: $channelDescription)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if channelDescription.isEmpty {
                                Text(String(localized: "介绍这个频道的用途、规则等…"))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // MARK: 频道设置
                Section(header: Text(String(localized: "频道设置")),
                        footer: Text(String(localized: "channel.settings.hint"))
                            .foregroundColor(.secondary)) {
                    Toggle(String(localized: "公开频道"), isOn: $isPublic)
                        .padding(.vertical, 2)
                    Toggle(String(localized: "需要审批加入"), isOn: $requiresApproval)
                        .padding(.vertical, 2)
                }

                // MARK: 错误提示
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ApocalypseTheme.danger)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "创建频道"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if !isFullyUnlocked(for: selectedType) {
                            showUnlockAlert = true
                        } else {
                            createChannel()
                        }
                    } label: {
                        if isCreating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(String(localized: "创建"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(String(localized: "设备未解锁"), isPresented: $showUnlockAlert) {
            Button(String(localized: "知道了"), role: .cancel) {}
        } message: {
            Text(unlockAlertMessage)
        }
    }

    // MARK: - 创建

    private func createChannel() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = String(localized: "用户未登录")
            return
        }
        guard isValidName else {
            errorMessage = String(localized: "请输入有效的频道名称")
            return
        }
        guard isFullyUnlocked(for: selectedType) else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await communicationManager.createChannel(
                    creatorId: userId,
                    channelType: selectedType,
                    name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: channelDescription.isEmpty ? nil : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    latitude: locationManager.userLocation?.latitude,
                    longitude: locationManager.userLocation?.longitude,
                    isPublic: isPublic,
                    requiresApproval: requiresApproval
                )
                await MainActor.run { dismiss() }
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
