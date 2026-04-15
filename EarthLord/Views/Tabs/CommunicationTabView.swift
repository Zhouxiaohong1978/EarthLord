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

    @State private var showCallsignSheet = false
    @State private var showCreateChannelSheet = false
    @State private var showAdminBroadcast = false
    @State private var isSendingTestBroadcast = false
    @AppStorage("voiceBroadcastEnabled") private var voiceBroadcastEnabled = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航
                VStack(spacing: 0) {
                    HStack {
                        Text(LocalizedStringKey("通讯中心"))
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

                        // 三点菜单
                        Menu {
                            Button(action: { showCallsignSheet = true }) {
                                Label("呼号设置", systemImage: "antenna.radiowaves.left.and.right")
                            }
                            Button(action: { showCreateChannelSheet = true }) {
                                Label("创建频道", systemImage: "plus.circle")
                            }
                            Button(action: {
                                voiceBroadcastEnabled.toggle()
                                communicationManager.setVoiceBroadcast(enabled: voiceBroadcastEnabled)
                            }) {
                                Label(
                                    voiceBroadcastEnabled ? "关闭语音播报" : "开启语音播报",
                                    systemImage: voiceBroadcastEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill"
                                )
                            }
                            Button(action: sendTestBroadcast) {
                                Label("生成测试广播", systemImage: "waveform")
                            }
                            if authManager.isAdmin {
                                Divider()
                                Button(action: { showAdminBroadcast = true }) {
                                    Label("发布官方消息", systemImage: "megaphone.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(ApocalypseTheme.primary)
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
                                    Text(LocalizedStringKey(section.rawValue))
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
            communicationManager.setVoiceBroadcast(enabled: voiceBroadcastEnabled)
            if let userId = authManager.currentUser?.id {
                Task {
                    await communicationManager.ensureDevicesInitialized()
                    await communicationManager.ensureOfficialChannelSubscribed(userId: userId)
                    await communicationManager.loadCallsign(userId: userId)
                }
            }
        }
        .sheet(isPresented: $showCallsignSheet) {
            CallsignEditView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showCreateChannelSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showAdminBroadcast) {
            AdminBroadcastView()
        }
    }

    private func sendTestBroadcast() {
        let callsign = communicationManager.displayCallsign
        let testContent = "测试广播，来自 \(callsign)，通讯设备工作正常。"
        communicationManager.speakText(testContent)
    }
}

#Preview {
    CommunicationTabView()
        .environmentObject(AuthManager.shared)
}
