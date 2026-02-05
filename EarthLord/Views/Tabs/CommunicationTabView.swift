//
//  CommunicationTabView.swift
//  EarthLord
//
//  通讯系统主页面 - 提供消息、频道、呼叫、设备四个导航分区
//

import SwiftUI
import Supabase

struct CommunicationTabView: View {
    @State private var selectedSection: CommunicationSection = .messages
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航
                VStack(spacing: 0) {
                    HStack {
                        Text("通讯中心")
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        // 当前设备指示器
                        if let device = communicationManager.currentDevice {
                            HStack(spacing: 4) {
                                Image(systemName: device.deviceType.iconName)
                                    .font(.system(size: 12))
                                Text(device.deviceType.rangeText)
                                    .font(.caption)
                            }
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // 导航按钮
                    HStack(spacing: 0) {
                        ForEach(CommunicationSection.allCases, id: \.self) { section in
                            Button(action: { selectedSection = section }) {
                                VStack(spacing: 4) {
                                    Image(systemName: section.iconName)
                                        .font(.system(size: 20))
                                    Text(section.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(selectedSection == section ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedSection == section ? ApocalypseTheme.primary.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)

                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.3))
                }
                .background(ApocalypseTheme.cardBackground)

                // 内容区域
                NavigationStack {
                    switch selectedSection {
                    case .messages:
                        MessageCenterView()
                    case .channels:
                        ChannelCenterView()
                    case .call:
                        PTTCallView()
                    case .devices:
                        DeviceManagementView()
                    }
                }
                .tint(ApocalypseTheme.primary)
            }
        }
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await communicationManager.ensureDevicesInitialized()
                    // Day 36-A：确保订阅官方频道
                    await communicationManager.ensureOfficialChannelSubscribed(userId: userId)
                    // Day 36：加载用户呼号
                    await communicationManager.loadCallsign(userId: userId)
                }
            }
        }
    }
}

#Preview {
    CommunicationTabView()
        .environmentObject(AuthManager.shared)
}
