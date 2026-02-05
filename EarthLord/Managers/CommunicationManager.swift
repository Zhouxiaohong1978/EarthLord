//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯管理器 - 管理通讯设备和通讯功能
//

import Foundation
import Supabase
import Realtime
import Combine
import CoreLocation

// MARK: - CommunicationManager

/// 通讯管理器（单例）
@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = CommunicationManager()

    // MARK: - Constants

    /// 官方频道固定 UUID（Day 36）
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    // MARK: - Published Properties

    /// 用户的通讯设备列表
    @Published var devices: [CommunicationDevice] = []

    /// 当前选中的设备
    @Published var currentDevice: CommunicationDevice?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Channel Properties

    /// 所有活跃频道列表
    @Published var channels: [CommunicationChannel] = []

    /// 用户订阅的频道（含订阅信息）
    @Published var subscribedChannels: [SubscribedChannel] = []

    /// 用户的订阅列表
    @Published var mySubscriptions: [ChannelSubscription] = []

    // MARK: - Message Properties

    /// 频道消息缓存（channelId -> messages）
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]

    /// 是否正在发送消息
    @Published var isSendingMessage: Bool = false

    // MARK: - Day 36 Properties

    /// 用户呼号
    @Published var userCallsign: String?

    /// 频道预览列表（消息中心使用）
    @Published var channelPreviews: [ChannelPreview] = []

    // MARK: - Realtime Properties

    /// Realtime 频道
    private var realtimeChannel: RealtimeChannelV2?

    /// 消息订阅任务
    private var messageSubscriptionTask: Task<Void, Never>?

    /// 已订阅消息推送的频道ID集合
    @Published var subscribedChannelIds: Set<UUID> = []

    // MARK: - Private Properties

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// 日志器
    private let logger = ExplorationLogger.shared

    // MARK: - Initialization

    private init() {
        logger.log("CommunicationManager 初始化完成", type: .info)
    }

    // MARK: - Load Devices

    /// 加载用户的通讯设备
    /// - Parameter userId: 用户ID
    /// - Returns: 设备列表
    @discardableResult
    func loadDevices(userId: UUID) async throws -> [CommunicationDevice] {
        logger.log("加载通讯设备...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [CommunicationDeviceDB] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let loadedDevices = response.compactMap { $0.toCommunicationDevice() }
                .sorted { $0.deviceType.sortOrder < $1.deviceType.sortOrder }

            self.devices = loadedDevices
            self.currentDevice = loadedDevices.first { $0.isCurrent }

            logger.log("成功加载 \(loadedDevices.count) 个通讯设备", type: .success)

            return loadedDevices

        } catch {
            logger.logError("加载通讯设备失败", error: error)
            throw CommunicationError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - Initialize Devices

    /// 初始化用户的通讯设备（首次使用时调用）
    /// - Parameter userId: 用户ID
    /// - Returns: 初始化后的设备列表
    @discardableResult
    func initializeDevices(userId: UUID) async throws -> [CommunicationDevice] {
        logger.log("初始化通讯设备...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [CommunicationDeviceDB] = try await supabase
                .rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString])
                .execute()
                .value

            let initializedDevices = response.compactMap { $0.toCommunicationDevice() }
                .sorted { $0.deviceType.sortOrder < $1.deviceType.sortOrder }

            self.devices = initializedDevices
            self.currentDevice = initializedDevices.first { $0.isCurrent }

            logger.log("成功初始化 \(initializedDevices.count) 个通讯设备", type: .success)

            return initializedDevices

        } catch {
            logger.logError("初始化通讯设备失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Switch Device

    /// 切换当前使用的设备
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 目标设备类型
    func switchDevice(userId: UUID, to deviceType: DeviceType) async throws {
        logger.log("切换通讯设备到: \(deviceType.displayName)", type: .info)

        // 检查设备是否已解锁
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            throw CommunicationError.deviceLocked
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let _: Bool = try await supabase
                .rpc("switch_current_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()
                .value

            // 更新本地状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first { $0.deviceType == deviceType }

            logger.log("成功切换到设备: \(deviceType.displayName)", type: .success)

        } catch {
            logger.logError("切换设备失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Unlock Device

    /// 解锁设备
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 设备类型
    func unlockDevice(userId: UUID, deviceType: DeviceType) async throws {
        logger.log("解锁通讯设备: \(deviceType.displayName)", type: .info)

        isLoading = true
        defer { isLoading = false }

        do {
            let _: Bool = try await supabase
                .rpc("unlock_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()
                .value

            // 更新本地状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }

            logger.log("成功解锁设备: \(deviceType.displayName)", type: .success)

        } catch {
            logger.logError("解锁设备失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Upgrade Device

    /// 升级设备等级
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 设备类型
    func upgradeDevice(userId: UUID, deviceType: DeviceType) async throws {
        logger.log("升级通讯设备: \(deviceType.displayName)", type: .info)

        guard let device = devices.first(where: { $0.deviceType == deviceType }) else {
            throw CommunicationError.deviceNotFound
        }

        guard device.isUnlocked else {
            throw CommunicationError.deviceLocked
        }

        let newLevel = device.deviceLevel + 1
        guard newLevel <= 10 else {
            logger.log("设备已达最高等级", type: .warning)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("communication_devices")
                .update(["device_level": newLevel])
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 更新本地状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].deviceLevel = newLevel
                if devices[index].isCurrent {
                    currentDevice = devices[index]
                }
            }

            logger.log("成功升级设备到等级 \(newLevel)", type: .success)

        } catch {
            logger.logError("升级设备失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType? {
        return currentDevice?.deviceType
    }

    /// 检查当前设备是否可以发送消息
    func canSendMessage() -> Bool {
        return currentDevice?.canSend ?? false
    }

    /// 获取当前通讯范围
    func getCurrentRange() -> Double {
        return currentDevice?.currentRange ?? 0
    }

    /// 检查指定设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        return devices.first { $0.deviceType == deviceType }?.isUnlocked ?? false
    }

    /// 获取指定设备
    func getDevice(_ deviceType: DeviceType) -> CommunicationDevice? {
        return devices.first { $0.deviceType == deviceType }
    }

    /// 获取所有已解锁的设备
    func getUnlockedDevices() -> [CommunicationDevice] {
        return devices.filter { $0.isUnlocked }
    }

    /// 检查是否有任何设备已解锁
    func hasAnyUnlockedDevice() -> Bool {
        return devices.contains { $0.isUnlocked }
    }

    // MARK: - Refresh

    /// 刷新所有数据
    func refresh() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }

        do {
            _ = try await loadDevices(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 确保设备已初始化
    /// 如果设备列表为空，则初始化设备
    func ensureDevicesInitialized() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }

        do {
            // 先尝试加载
            let loadedDevices = try await loadDevices(userId: userId)

            // 如果没有设备，则初始化
            if loadedDevices.isEmpty {
                _ = try await initializeDevices(userId: userId)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset

    /// 重置管理器状态
    func reset() {
        devices = []
        currentDevice = nil
        channels = []
        subscribedChannels = []
        mySubscriptions = []
        channelMessages = [:]
        isSendingMessage = false
        subscribedChannelIds = []
        stopRealtimeSubscription()
        isLoading = false
        errorMessage = nil
        logger.log("CommunicationManager 已重置", type: .info)
    }

    // MARK: - Channel Methods

    /// 加载所有活跃频道
    /// - Returns: 频道列表
    @discardableResult
    func loadPublicChannels() async throws -> [CommunicationChannel] {
        logger.log("加载公共频道...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.channels = response
            logger.log("成功加载 \(response.count) 个公共频道", type: .success)
            return response

        } catch {
            logger.logError("加载公共频道失败", error: error)
            throw CommunicationError.loadFailed(error.localizedDescription)
        }
    }

    /// 加载用户订阅的频道
    /// - Parameter userId: 用户ID
    /// - Returns: 订阅的频道列表
    @discardableResult
    func loadSubscribedChannels(userId: UUID) async throws -> [SubscribedChannel] {
        logger.log("加载订阅频道...", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [ChannelWithSubscription] = try await supabase
                .from("communication_channels")
                .select("*, channel_subscriptions!inner(*)")
                .eq("channel_subscriptions.user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            let subscribedList = response.compactMap { $0.toSubscribedChannel() }
            self.subscribedChannels = subscribedList
            self.mySubscriptions = subscribedList.map { $0.subscription }

            logger.log("成功加载 \(subscribedList.count) 个订阅频道", type: .success)
            return subscribedList

        } catch {
            logger.logError("加载订阅频道失败", error: error)
            throw CommunicationError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - 官方频道相关（Day 36）

    /// 确保用户订阅了官方频道（强制订阅）
    /// - Parameter userId: 用户ID
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        let officialId = CommunicationManager.officialChannelId

        // 检查是否已订阅
        if subscribedChannels.contains(where: { $0.channel.id == officialId }) {
            logger.log("官方频道已订阅", type: .success)
            return
        }

        // 强制订阅官方频道
        do {
            let params: [String: String] = [
                "p_user_id": userId.uuidString,
                "p_channel_id": officialId.uuidString
            ]

            try await supabase.rpc("subscribe_to_channel", params: params).execute()

            // 刷新订阅列表
            _ = try await loadSubscribedChannels(userId: userId)
            logger.log("官方频道已自动订阅", type: .success)
        } catch {
            logger.logError("官方频道订阅失败", error: error)
        }
    }

    /// 检查是否是官方频道
    /// - Parameter channelId: 频道ID
    /// - Returns: 是否为官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        return channelId == CommunicationManager.officialChannelId
    }

    /// 创建频道
    /// - Parameters:
    ///   - creatorId: 创建者ID
    ///   - channelType: 频道类型
    ///   - name: 频道名称
    ///   - description: 频道描述（可选）
    /// - Returns: 新创建的频道ID
    @discardableResult
    func createChannel(
        creatorId: UUID,
        channelType: ChannelType,
        name: String,
        description: String? = nil
    ) async throws -> UUID {
        logger.log("创建频道: \(name)", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            let params: [String: AnyJSON] = [
                "p_creator_id": .string(creatorId.uuidString),
                "p_channel_type": .string(channelType.rawValue),
                "p_name": .string(name),
                "p_description": description != nil ? .string(description!) : .null
            ]

            let channelIdString: String = try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            guard let channelId = UUID(uuidString: channelIdString) else {
                throw CommunicationError.saveFailed("无效的频道ID")
            }

            // 刷新频道列表
            _ = try? await loadPublicChannels()
            _ = try? await loadSubscribedChannels(userId: creatorId)

            logger.log("成功创建频道: \(channelId)", type: .success)
            return channelId

        } catch {
            logger.logError("创建频道失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 订阅频道
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - channelId: 频道ID
    func subscribeToChannel(userId: UUID, channelId: UUID) async throws {
        logger.log("订阅频道: \(channelId)", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("channel_subscriptions")
                .insert([
                    "user_id": userId.uuidString,
                    "channel_id": channelId.uuidString
                ])
                .execute()

            // 刷新订阅列表
            _ = try? await loadSubscribedChannels(userId: userId)
            _ = try? await loadPublicChannels()

            logger.log("成功订阅频道", type: .success)

        } catch {
            logger.logError("订阅频道失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 取消订阅频道
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - channelId: 频道ID
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async throws {
        logger.log("取消订阅频道: \(channelId)", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("channel_subscriptions")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("channel_id", value: channelId.uuidString)
                .execute()

            // 更新本地状态
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }

            // 刷新频道列表以更新成员数
            _ = try? await loadPublicChannels()

            logger.log("成功取消订阅频道", type: .success)

        } catch {
            logger.logError("取消订阅频道失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 删除频道
    /// - Parameter channelId: 频道ID
    func deleteChannel(channelId: UUID) async throws {
        logger.log("删除频道: \(channelId)", type: .info)
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            // 更新本地状态
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }

            logger.log("成功删除频道", type: .success)

        } catch {
            logger.logError("删除频道失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 检查是否已订阅指定频道
    /// - Parameter channelId: 频道ID
    /// - Returns: 是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        return mySubscriptions.contains { $0.channelId == channelId }
    }

    /// 获取指定频道
    /// - Parameter channelId: 频道ID
    /// - Returns: 频道（如果存在）
    func getChannel(_ channelId: UUID) -> CommunicationChannel? {
        return channels.first { $0.id == channelId }
    }

    /// 刷新频道数据
    func refreshChannels() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }

        do {
            _ = try await loadPublicChannels()
            _ = try await loadSubscribedChannels(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Message Methods

    /// 加载频道历史消息
    /// - Parameter channelId: 频道ID
    /// - Returns: 消息列表
    @discardableResult
    func loadChannelMessages(channelId: UUID) async throws -> [ChannelMessage] {
        logger.log("加载频道消息: \(channelId)", type: .info)

        do {
            let response: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(100)
                .execute()
                .value

            // 应用距离过滤（与 Realtime 逻辑一致）
            let channel = getChannel(channelId)
            let filtered = response.filter { shouldReceiveMessage($0, channel: channel) }
            channelMessages[channelId] = filtered
            logger.log("成功加载消息: 原始 \(response.count) 条, 过滤后 \(filtered.count) 条", type: .success)
            return filtered

        } catch {
            logger.logError("加载消息失败", error: error)
            throw CommunicationError.loadFailed(error.localizedDescription)
        }
    }

    /// 发送频道消息
    /// - Parameters:
    ///   - channelId: 频道ID
    ///   - content: 消息内容
    ///   - latitude: 发送位置纬度（可选）
    ///   - longitude: 发送位置经度（可选）
    /// - Returns: 消息ID
    @discardableResult
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> UUID {
        logger.log("发送消息到频道: \(channelId)", type: .info)
        isSendingMessage = true
        defer { isSendingMessage = false }

        // 获取当前设备类型
        let deviceTypeString = currentDevice?.deviceType.rawValue ?? "unknown"

        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_device_type": .string(deviceTypeString)
            ]

            // 🐛 DEBUG: 检查RPC参数
            if let lat = latitude, let lon = longitude {
                params["p_latitude"] = .double(lat)
                params["p_longitude"] = .double(lon)
                print("📍 [RPC] 传入位置参数: p_latitude=\(lat), p_longitude=\(lon)")
            } else {
                print("⚠️ [RPC] 位置参数为空: latitude=\(latitude as Any), longitude=\(longitude as Any)")
            }

            let messageIdString: String = try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            guard let messageId = UUID(uuidString: messageIdString) else {
                throw CommunicationError.saveFailed("无效的消息ID")
            }

            logger.log("成功发送消息: \(messageId)", type: .success)
            return messageId

        } catch {
            logger.logError("发送消息失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 获取频道消息列表
    /// - Parameter channelId: 频道ID
    /// - Returns: 消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        return channelMessages[channelId] ?? []
    }

    // MARK: - Distance Filtering (Day 35)

    /// 判断是否应该接收该消息（基于设备类型和距离）
    /// 只对公共频道应用距离过滤，私有频道不限制
    func shouldReceiveMessage(_ message: ChannelMessage, channel: CommunicationChannel?) -> Bool {
        // 0. 私有频道（非 public 类型）不应用距离过滤
        if let ch = channel, ch.channelType != .public {
            print("📌 [距离过滤] 非公共频道，跳过过滤")
            return true
        }

        // 1. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略
        }

        // 2. 收音机可以接收所有消息（无限距离）
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 3. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示（向后兼容）")
            return true  // 向后兼容
        }

        // 4. 收音机不能发送消息
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 5. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true  // 保守策略
        }

        // 6. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略
        }

        // 7. 计算距离（公里）
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(latitude: myLocation.latitude, longitude: myLocation.longitude),
            to: CLLocationCoordinate2D(latitude: senderLocation.latitude, longitude: senderLocation.longitude)
        )

        // 8. 根据设备矩阵判断（传入本地设备对象以获取含等级加成的范围）
        guard let myDevice = currentDevice else { return true }
        let canReceive = canReceiveMessage(senderDevice: senderDevice, myDevice: myDevice, distance: distance)

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km (超出范围)")
        }

        return canReceive
    }

    /// 根据设备类型矩阵判断是否能接收消息
    /// 有效范围 = max(发送者基础范围, 接收者实际范围)，含 5% 缓冲区
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: CommunicationDevice, distance: Double) -> Bool {
        // 收音机接收方：无距离限制
        if myDevice.deviceType == .radio {
            return true
        }

        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return false
        }

        // 取发送者基础范围和接收者实际范围（含等级加成）中的较大值，再加 5% 缓冲
        let senderRange = senderDevice.range
        let receiverRange = myDevice.currentRange
        let effectiveRange = max(senderRange, receiverRange) * 1.05

        return distance <= effectiveRange
    }

    /// 计算两个坐标之间的距离（公里）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0  // 转换为公里
    }

    /// 获取当前用户位置
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    // MARK: - Realtime Methods

    /// 启动 Realtime 订阅
    func startRealtimeSubscription() {
        guard realtimeChannel == nil else {
            logger.log("Realtime 已启动", type: .warning)
            return
        }

        logger.log("启动 Realtime 订阅...", type: .info)

        let channel = supabase.realtimeV2.channel("channel_messages")

        messageSubscriptionTask = Task { [weak self] in
            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "channel_messages"
            )

            try? await channel.subscribeWithError()

            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion)
            }
        }

        realtimeChannel = channel
        logger.log("Realtime 订阅已启动", type: .success)
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            Task {
                await supabase.realtimeV2.removeChannel(channel)
            }
        }
        realtimeChannel = nil
        logger.log("Realtime 订阅已停止", type: .info)
    }

    /// 处理新消息
    private func handleNewMessage(insertion: InsertAction) async {
        do {
            let decoder = JSONDecoder()
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 检查是否是已订阅的频道
            guard subscribedChannelIds.contains(message.channelId) else {
                return
            }

            // Day 35: 距离过滤
            let channel = getChannel(message.channelId)
            guard shouldReceiveMessage(message, channel: channel) else {
                logger.log("[Realtime] 距离过滤丢弃消息", type: .info)
                return
            }

            // 添加到本地缓存
            if channelMessages[message.channelId] != nil {
                // 检查是否已存在（防止重复）
                if !channelMessages[message.channelId]!.contains(where: { $0.messageId == message.messageId }) {
                    channelMessages[message.channelId]?.append(message)
                    logger.log("收到新消息: \(message.messageId)", type: .info)
                }
            } else {
                channelMessages[message.channelId] = [message]
            }

        } catch {
            logger.logError("解析新消息失败", error: error)
        }
    }

    /// 订阅频道消息推送
    /// - Parameter channelId: 频道ID
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)

        // 确保 Realtime 已启动
        if realtimeChannel == nil {
            startRealtimeSubscription()
        }

        logger.log("已订阅频道消息: \(channelId)", type: .info)
    }

    /// 取消订阅频道消息推送
    /// - Parameter channelId: 频道ID
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        logger.log("已取消订阅频道消息: \(channelId)", type: .info)

        // 如果没有任何订阅，停止 Realtime
        if subscribedChannelIds.isEmpty {
            stopRealtimeSubscription()
        }
    }

    // MARK: - Day 36: Message Center Methods

    /// 加载带预览的订阅频道列表（消息中心使用）
    @discardableResult
    func loadChannelPreviews(userId: UUID) async throws -> [ChannelPreview] {
        logger.log("加载频道预览列表...", type: .info)

        do {
            let response: [ChannelPreview] = try await supabase
                .rpc("get_subscribed_channels_with_preview", params: ["p_user_id": userId.uuidString])
                .execute()
                .value

            channelPreviews = response
            logger.log("成功加载 \(response.count) 个频道预览", type: .success)
            return response

        } catch {
            logger.logError("加载频道预览失败", error: error)
            throw CommunicationError.loadFailed(error.localizedDescription)
        }
    }

    /// 标记频道为已读
    func markChannelAsRead(userId: UUID, channelId: UUID) async {
        do {
            try await supabase.rpc("mark_channel_read", params: [
                "p_user_id": userId.uuidString,
                "p_channel_id": channelId.uuidString
            ]).execute()

            logger.log("标记频道已读: \(channelId)", type: .success)
        } catch {
            logger.logError("标记已读失败", error: error)
        }
    }

    // MARK: - Day 36: Callsign Methods

    /// 初始化用户呼号
    @discardableResult
    func initializeCallsign(userId: UUID) async throws -> String {
        logger.log("初始化用户呼号...", type: .info)

        do {
            let callsign: String = try await supabase
                .rpc("initialize_user_callsign", params: ["p_user_id": userId.uuidString])
                .execute()
                .value

            userCallsign = callsign
            logger.log("呼号初始化成功: \(callsign)", type: .success)
            return callsign

        } catch {
            logger.logError("初始化呼号失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    /// 加载用户呼号
    func loadCallsign(userId: UUID) async {
        do {
            struct CallsignResult: Codable {
                let callsign: String?
            }

            let result: [CallsignResult] = try await supabase
                .from("profiles")
                .select("callsign")
                .eq("id", value: userId.uuidString)
                .execute()
                .value

            userCallsign = result.first?.callsign

            // 如果没有呼号，自动初始化
            if userCallsign == nil {
                _ = try await initializeCallsign(userId: userId)
            }

            logger.log("呼号加载成功: \(userCallsign ?? "无")", type: .success)
        } catch {
            logger.logError("加载呼号失败", error: error)
        }
    }

    /// 更新用户呼号
    func updateCallsign(userId: UUID, newCallsign: String) async throws {
        logger.log("更新用户呼号: \(newCallsign)", type: .info)

        do {
            let success: Bool = try await supabase
                .rpc("update_user_callsign", params: [
                    "p_user_id": userId.uuidString,
                    "p_callsign": newCallsign
                ])
                .execute()
                .value

            if success {
                userCallsign = newCallsign
                logger.log("呼号更新成功", type: .success)
            }

        } catch {
            logger.logError("更新呼号失败", error: error)
            throw CommunicationError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Day 36: Official Channel Methods

    /// 加载官方频道消息（支持分类过滤）
    func loadOfficialMessages(category: MessageCategory? = nil) async throws -> [ChannelMessage] {
        logger.log("加载官方频道消息, 分类: \(category?.rawValue ?? "全部")", type: .info)

        let response: [ChannelMessage] = try await supabase
            .from("channel_messages")
            .select()
            .eq("channel_id", value: CommunicationManager.officialChannelId.uuidString)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        // 客户端过滤分类（因为 metadata 是 JSONB）
        let filtered: [ChannelMessage]
        if let category = category {
            filtered = response.filter { $0.category == category }
        } else {
            filtered = response
        }

        channelMessages[CommunicationManager.officialChannelId] = filtered.reversed()
        logger.log("成功加载 \(filtered.count) 条官方消息", type: .success)
        return filtered.reversed()
    }

    // MARK: - Day 36: PTT Methods

    /// 发送PTT快捷消息
    func sendPTTMessage(content: String, isEmergency: Bool = false) async throws -> UUID {
        logger.log("发送PTT消息: \(content.prefix(20))..., 紧急: \(isEmergency)", type: .info)

        guard let device = currentDevice, device.canSend else {
            throw CommunicationError.cannotSend
        }

        // 获取当前位置
        let location = LocationManager.shared.userLocation

        // 查找目标频道（第一个公共频道或官方频道）
        let targetChannel = subscribedChannels.first { $0.channel.channelType == .public }?.channel.id
            ?? CommunicationManager.officialChannelId

        // 紧急消息添加前缀
        let finalContent = isEmergency ? "[紧急] \(content)" : content

        return try await sendChannelMessage(
            channelId: targetChannel,
            content: finalContent,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
    }
}
