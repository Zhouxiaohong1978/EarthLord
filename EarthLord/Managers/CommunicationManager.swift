//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯管理器 - 管理通讯设备和通讯功能
//

import Foundation
import Supabase
import Combine

// MARK: - CommunicationManager

/// 通讯管理器（单例）
@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = CommunicationManager()

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
}
