//
//  ExplorationShareSheet.swift
//  EarthLord
//
//  搜刮完成后分享探索发现到通讯频道

import SwiftUI

struct ExplorationShareSheet: View {
    let result: ScavengeResult

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var commManager = CommunicationManager.shared

    @State private var selectedChannelId: UUID? = nil
    @State private var isSending = false
    @State private var didSend = false

    /// 只显示当前设备范围内的订阅频道
    private var reachableChannels: [SubscribedChannel] {
        guard let playerLoc = LocationManager.shared.userLocation,
              let deviceRange = commManager.currentDevice?.currentRange else {
            return commManager.subscribedChannels
        }
        return commManager.subscribedChannels.filter { sub in
            guard let dist = sub.channel.distance(from: playerLoc) else { return true }
            return dist <= deviceRange
        }
    }

    private var broadcastContent: String {
        let poiName = result.poi.name
        let isEn = Locale.current.language.languageCode?.identifier == "en"
        let separator = isEn ? ", " : "、"
        let itemSummary = result.items.prefix(3).map { item in
            let name = item.localizedName.isEmpty ? String(localized: "物品") : item.localizedName
            return "\(name)×\(item.quantity)"
        }.joined(separator: separator)
        let extra = result.items.count > 3 ? String(format: String(localized: "等%d件"), result.items.count) : ""
        return String(format: String(localized: "【探索发现】在「%@」搜到 %@%@"), poiName, itemSummary, extra)
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "分享探索发现"))
                            .font(.headline).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        if let device = commManager.currentDevice {
                            Text(String(format: String(localized: "当前设备：%@ (%@)"), device.deviceType.displayName, device.deviceType.rangeText))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    Spacer()
                    Button(String(localized: "跳过")) { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // 预览内容
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(broadcastContent)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.08))

                if commManager.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "加载频道中…"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else if reachableChannels.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 32))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(localized: "当前设备范围内无可用频道"))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(localized: "升级设备可扩大覆盖范围"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(reachableChannels) { sub in
                                channelRow(sub)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }

                Divider().background(Color.white.opacity(0.08))

                // 发送按钮
                Button {
                    guard let channelId = selectedChannelId else { return }
                    send(to: channelId)
                } label: {
                    Group {
                        if isSending {
                            ProgressView().scaleEffect(0.85)
                        } else if didSend {
                            Label(String(localized: "已分享"), systemImage: "checkmark")
                        } else {
                            Text(String(localized: "分享到频道"))
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedChannelId == nil ? Color.gray.opacity(0.4) : ApocalypseTheme.success)
                    )
                }
                .disabled(selectedChannelId == nil || isSending || didSend)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            // 频道未加载时主动刷新，确保用户能看到可用频道
            if commManager.subscribedChannels.isEmpty {
                Task { await commManager.refreshChannels() }
            }
        }
    }

    @ViewBuilder
    private func channelRow(_ sub: SubscribedChannel) -> some View {
        let isSelected = selectedChannelId == sub.channel.id
        Button {
            selectedChannelId = sub.channel.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.channel.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    if let loc = LocationManager.shared.userLocation,
                       let dist = sub.channel.distance(from: loc) {
                        Text(String(format: "%.1f km", dist))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                Spacer()
                Text(sub.channel.channelType.displayName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? ApocalypseTheme.success.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func send(to channelId: UUID) {
        isSending = true
        Task {
            // 直接存 GCJ-02 坐标：MapKit/MKPlacemark 在中国设备上统一使用 GCJ-02
            try? await CommunicationManager.shared.sendChannelMessage(
                channelId: channelId,
                content: broadcastContent,
                latitude: result.poi.coordinate.latitude,
                longitude: result.poi.coordinate.longitude,
                messageType: "system"
            )
            await MainActor.run {
                isSending = false
                didSend = true
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { dismiss() }
        }
    }
}
