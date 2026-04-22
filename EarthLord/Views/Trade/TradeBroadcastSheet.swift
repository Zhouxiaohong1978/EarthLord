//
//  TradeBroadcastSheet.swift
//  EarthLord
//
//  挂单成功后推送到通讯频道的选择 Sheet

import SwiftUI

struct TradeBroadcastSheet: View {
    let offer: TradeOffer
    var onDone: (() -> Void)? = nil   // 推送/跳过后额外回调（如关闭父视图）

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var commManager = CommunicationManager.shared

    @State private var selectedChannelId: UUID? = nil
    @State private var isSending = false
    @State private var didSend = false

    private var subscribedChannels: [SubscribedChannel] {
        commManager.subscribedChannels
    }

    private func localizedItemName(_ item: TradeItem) -> String {
        if let custom = item.customName { return custom }
        return MockExplorationData.getItemDefinition(by: item.itemId)?.name ?? item.itemId
    }

    private var broadcastContent: String {
        let offering = offer.offeringItems.map { item in
            "\(localizedItemName(item))×\(item.quantity)"
        }.joined(separator: " + ")

        let requesting = offer.requestingItems.map { item in
            "\(localizedItemName(item))×\(item.quantity)"
        }.joined(separator: " + ")

        return String(format: String(localized: "【挂单】%@ 换 %@，有意联系"), offering, requesting)
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text(String(localized: "推送到频道"))
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                    Button(String(localized: "跳过")) { dismiss(); onDone?() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                // 预览内容
                Text(broadcastContent)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.08))

                if subscribedChannels.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 32))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(localized: "尚未订阅任何频道"))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(subscribedChannels) { sub in
                                channelRow(sub)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
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
                            Label(String(localized: "已发送"), systemImage: "checkmark")
                        } else {
                            Text(String(localized: "发送到频道"))
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedChannelId == nil ? Color.gray.opacity(0.4) : ApocalypseTheme.primary)
                    )
                }
                .disabled(selectedChannelId == nil || isSending || didSend)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.channel.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(sub.channel.channelType.displayName)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? ApocalypseTheme.primary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func send(to channelId: UUID) {
        isSending = true
        Task {
            let loc = LocationManager.shared.userLocation
            try? await CommunicationManager.shared.sendChannelMessage(
                channelId: channelId,
                content: broadcastContent,
                latitude: loc?.latitude,
                longitude: loc?.longitude
            )
            await MainActor.run {
                isSending = false
                didSend = true
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                dismiss()
                onDone?()
            }
        }
    }
}
