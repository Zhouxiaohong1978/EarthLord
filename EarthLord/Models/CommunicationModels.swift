//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  包含：设备类型、通讯设备、导航分区
//

import Foundation
import SwiftUI

// MARK: - DeviceType 设备类型

/// 通讯设备类型枚举
enum DeviceType: String, Codable, CaseIterable, Identifiable {
    case radio = "radio"                    // 收音机（被动收听）
    case walkieTalkie = "walkie_talkie"     // 对讲机（短距离通讯）
    case campRadio = "camp_radio"           // 营地电台（中距离通讯）
    case satellite = "satellite"            // 卫星电话（全球通讯）

    var id: String { rawValue }

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .radio:
            return String(localized: "收音机")
        case .walkieTalkie:
            return String(localized: "对讲机")
        case .campRadio:
            return String(localized: "营地电台")
        case .satellite:
            return String(localized: "卫星电话")
        }
    }

    /// 设备描述
    var description: String {
        switch self {
        case .radio:
            return String(localized: "被动收听广播和紧急信号")
        case .walkieTalkie:
            return String(localized: "与附近幸存者实时通讯")
        case .campRadio:
            return String(localized: "与更远距离的营地联系")
        case .satellite:
            return String(localized: "全球范围的紧急通讯")
        }
    }

    /// 设备图标
    var icon: String {
        switch self {
        case .radio:
            return "radio"
        case .walkieTalkie:
            return "antenna.radiowaves.left.and.right"
        case .campRadio:
            return "antenna.radiowaves.left.and.right.circle"
        case .satellite:
            return "globe"
        }
    }

    /// 通讯范围（公里）
    var range: Double {
        switch self {
        case .radio:
            return Double.infinity  // 收音机无限制接收
        case .walkieTalkie:
            return 3.0        // 对讲机短距离
        case .campRadio:
            return 30.0       // 营地电台中距离
        case .satellite:
            return 100.0      // 卫星电话全球
        }
    }

    /// 是否可以发送消息
    var canSend: Bool {
        switch self {
        case .radio:
            return false      // 收音机只能接收
        case .walkieTalkie, .campRadio, .satellite:
            return true
        }
    }

    /// 解锁所需等级
    var requiredLevel: Int {
        switch self {
        case .radio:
            return 1          // 默认解锁
        case .walkieTalkie:
            return 5
        case .campRadio:
            return 15
        case .satellite:
            return 30
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .radio:
            return ApocalypseTheme.info
        case .walkieTalkie:
            return ApocalypseTheme.success
        case .campRadio:
            return ApocalypseTheme.warning
        case .satellite:
            return ApocalypseTheme.primary
        }
    }

    /// 排序顺序
    var sortOrder: Int {
        switch self {
        case .radio:
            return 1
        case .walkieTalkie:
            return 2
        case .campRadio:
            return 3
        case .satellite:
            return 4
        }
    }

    /// 图标名称（别名，用于 UI）
    var iconName: String { icon }

    /// 通讯范围文本
    var rangeText: String {
        switch self {
        case .radio:
            return "无限制 (仅接收)"
        case .walkieTalkie:
            return "3km"
        case .campRadio:
            return "30km"
        case .satellite:
            return "全球"
        }
    }

    /// 解锁需求说明
    var unlockRequirement: String {
        switch self {
        case .radio:
            return "默认解锁"
        case .walkieTalkie:
            return "需要达到 5 级解锁"
        case .campRadio:
            return "需要达到 15 级解锁"
        case .satellite:
            return "需要达到 30 级解锁"
        }
    }
}

// MARK: - CommunicationDevice 通讯设备

/// 通讯设备模型（数据库映射）
struct CommunicationDevice: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        deviceType: DeviceType,
        deviceLevel: Int = 1,
        isUnlocked: Bool = false,
        isCurrent: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.deviceType = deviceType
        self.deviceLevel = deviceLevel
        self.isUnlocked = isUnlocked
        self.isCurrent = isCurrent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - 计算属性

    /// 当前通讯范围（考虑等级加成）
    var currentRange: Double {
        let baseRange = deviceType.range
        if baseRange == Double.infinity {
            return baseRange
        }
        // 每级增加10%范围
        return baseRange * (1.0 + Double(deviceLevel - 1) * 0.1)
    }

    /// 是否可以发送消息
    var canSend: Bool {
        return isUnlocked && deviceType.canSend
    }

    /// 格式化的通讯范围
    var formattedRange: String {
        if deviceType.range == Double.infinity {
            return String(localized: "全球")
        }
        return String(format: "%.1f km", currentRange)
    }
}

// MARK: - CommunicationDeviceDB 数据库模型

/// 通讯设备数据库模型（用于 Supabase）
struct CommunicationDeviceDB: Codable {
    let id: String?
    let userId: String
    let deviceType: String
    let deviceLevel: Int
    let isUnlocked: Bool
    let isCurrent: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为 CommunicationDevice
    func toCommunicationDevice() -> CommunicationDevice? {
        guard let idString = id,
              let id = UUID(uuidString: idString),
              let userId = UUID(uuidString: userId),
              let deviceType = DeviceType(rawValue: deviceType) else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let created = createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updated = updatedAt.flatMap { dateFormatter.date(from: $0) } ?? Date()

        return CommunicationDevice(
            id: id,
            userId: userId,
            deviceType: deviceType,
            deviceLevel: deviceLevel,
            isUnlocked: isUnlocked,
            isCurrent: isCurrent,
            createdAt: created,
            updatedAt: updated
        )
    }
}

// MARK: - CommunicationSection 通讯导航分区

/// 通讯页面导航分区
enum CommunicationSection: String, CaseIterable, Identifiable {
    case messages = "消息"       // 消息中心
    case channels = "频道"       // 频道中心
    case call = "呼叫"           // PTT呼叫
    case devices = "设备"        // 设备管理

    var id: String { rawValue }

    /// 本地化显示名称
    var displayName: String {
        return rawValue
    }

    /// 分区图标
    var icon: String {
        switch self {
        case .messages:
            return "bell.fill"
        case .channels:
            return "dot.radiowaves.left.and.right"
        case .call:
            return "phone.fill"
        case .devices:
            return "antenna.radiowaves.left.and.right"
        }
    }

    /// 图标名称（别名）
    var iconName: String { icon }

    /// 分区颜色
    var color: Color {
        switch self {
        case .messages:
            return ApocalypseTheme.info
        case .channels:
            return ApocalypseTheme.success
        case .call:
            return ApocalypseTheme.warning
        case .devices:
            return ApocalypseTheme.primary
        }
    }

    /// 是否需要设备支持发送
    var requiresSendCapability: Bool {
        switch self {
        case .messages:
            return false  // 消息只需要接收
        case .channels, .call, .devices:
            return true   // 其他需要发送能力
        }
    }
}

// MARK: - CommunicationError 错误类型

/// 通讯操作错误类型
enum CommunicationError: LocalizedError {
    case notAuthenticated           // 未登录
    case deviceNotFound             // 设备不存在
    case deviceLocked               // 设备未解锁
    case cannotSend                 // 当前设备无法发送
    case outOfRange                 // 超出通讯范围
    case saveFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "用户未登录")
        case .deviceNotFound:
            return String(localized: "设备不存在")
        case .deviceLocked:
            return String(localized: "设备未解锁")
        case .cannotSend:
            return String(localized: "当前设备无法发送消息")
        case .outOfRange:
            return String(localized: "超出通讯范围")
        case .saveFailed(let message):
            return String(format: String(localized: "保存失败: %@"), message)
        case .loadFailed(let message):
            return String(format: String(localized: "加载失败: %@"), message)
        }
    }
}

// MARK: - ChannelType 频道类型

/// 频道类型枚举
enum ChannelType: String, Codable, CaseIterable, Identifiable {
    case official = "official"      // 官方频道
    case `public` = "public"        // 公共频道
    case walkie = "walkie"          // 对讲频道
    case camp = "camp"              // 营地频道
    case satellite = "satellite"    // 卫星频道

    var id: String { rawValue }

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .official:
            return String(localized: "官方频道")
        case .public:
            return String(localized: "公共频道")
        case .walkie:
            return String(localized: "对讲频道")
        case .camp:
            return String(localized: "营地频道")
        case .satellite:
            return String(localized: "卫星频道")
        }
    }

    /// 频道图标
    var icon: String {
        switch self {
        case .official:
            return "megaphone.fill"
        case .public:
            return "antenna.radiowaves.left.and.right"
        case .walkie:
            return "walkie.talkie.fill"
        case .camp:
            return "tent.fill"
        case .satellite:
            return "globe"
        }
    }

    /// 频道颜色
    var color: Color {
        switch self {
        case .official:
            return ApocalypseTheme.primary
        case .public:
            return ApocalypseTheme.success
        case .walkie:
            return ApocalypseTheme.warning
        case .camp:
            return ApocalypseTheme.info
        case .satellite:
            return Color.purple
        }
    }

    /// 频道描述
    var description: String {
        switch self {
        case .official:
            return String(localized: "官方发布的重要信息")
        case .public:
            return String(localized: "所有人可见的公共频道")
        case .walkie:
            return String(localized: "短距离实时通讯")
        case .camp:
            return String(localized: "营地内部通讯")
        case .satellite:
            return String(localized: "全球范围通讯")
        }
    }

    /// 用户可创建的频道类型（排除官方）
    static var creatableTypes: [ChannelType] {
        return [.public, .walkie, .camp, .satellite]
    }
}

// MARK: - CommunicationChannel 频道模型

/// 通讯频道模型
struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    // MARK: - Hashable 实现（基于 id，因为 Date 不是 Hashable）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        creatorId = try container.decode(UUID.self, forKey: .creatorId)

        let typeString = try container.decode(String.self, forKey: .channelType)
        channelType = ChannelType(rawValue: typeString) ?? .public

        channelCode = try container.decode(String.self, forKey: .channelCode)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0

        // 解析日期
        if let createdString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: createdString) ?? Date()
        } else {
            createdAt = Date()
        }

        if let updatedString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: updatedString) ?? Date()
        } else {
            updatedAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(channelType.rawValue, forKey: .channelType)
        try container.encode(channelCode, forKey: .channelCode)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)
    }
}

// MARK: - ChannelSubscription 订阅模型

/// 频道订阅模型
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false

        if let joinedString = try? container.decode(String.self, forKey: .joinedAt) {
            joinedAt = ISO8601DateFormatter().date(from: joinedString) ?? Date()
        } else {
            joinedAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(channelId, forKey: .channelId)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(ISO8601DateFormatter().string(from: joinedAt), forKey: .joinedAt)
    }
}

// MARK: - SubscribedChannel 组合模型

/// 已订阅频道组合模型（频道+订阅信息）
struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - ChannelWithSubscription 数据库联合查询模型

/// 用于从数据库联合查询的模型
struct ChannelWithSubscription: Codable {
    let id: UUID
    let creatorId: UUID
    let channelType: String
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: String
    let updatedAt: String
    let subscriptions: [SubscriptionData]?

    struct SubscriptionData: Codable {
        let id: UUID
        let userId: UUID
        let isMuted: Bool
        let joinedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case isMuted = "is_muted"
            case joinedAt = "joined_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case subscriptions = "channel_subscriptions"
    }

    /// 转换为 SubscribedChannel
    func toSubscribedChannel() -> SubscribedChannel? {
        guard let subData = subscriptions?.first else { return nil }

        let formatter = ISO8601DateFormatter()

        let channel = CommunicationChannelData(
            id: id,
            creatorId: creatorId,
            channelType: ChannelType(rawValue: channelType) ?? .public,
            channelCode: channelCode,
            name: name,
            description: description,
            isActive: isActive,
            memberCount: memberCount,
            createdAt: formatter.date(from: createdAt) ?? Date(),
            updatedAt: formatter.date(from: updatedAt) ?? Date()
        )

        let subscription = ChannelSubscriptionData(
            id: subData.id,
            userId: subData.userId,
            channelId: id,
            isMuted: subData.isMuted,
            joinedAt: formatter.date(from: subData.joinedAt) ?? Date()
        )

        return SubscribedChannel(channel: channel.toCommunicationChannel(), subscription: subscription.toChannelSubscription())
    }
}

// MARK: - Helper Structs for Conversion

/// 频道数据辅助结构
private struct CommunicationChannelData {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    func toCommunicationChannel() -> CommunicationChannel {
        let jsonData = try! JSONEncoder().encode(self)
        return try! JSONDecoder().decode(CommunicationChannel.self, from: jsonData)
    }
}

extension CommunicationChannelData: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(channelType.rawValue, forKey: .channelType)
        try container.encode(channelCode, forKey: .channelCode)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)
    }
}

/// 订阅数据辅助结构
private struct ChannelSubscriptionData {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    func toChannelSubscription() -> ChannelSubscription {
        let jsonData = try! JSONEncoder().encode(self)
        return try! JSONDecoder().decode(ChannelSubscription.self, from: jsonData)
    }
}

extension ChannelSubscriptionData: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(channelId, forKey: .channelId)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(ISO8601DateFormatter().string(from: joinedAt), forKey: .joinedAt)
    }
}

// MARK: - LocationPoint 位置点模型

/// 位置点模型（用于消息位置）
struct LocationPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS WKT 格式解析：POINT(经度 纬度)
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

/// GeoJSON Point 格式（用于解码 Supabase geography 类型）
private struct GeoJSONPoint: Codable {
    let type: String
    let coordinates: [Double]  // [longitude, latitude]
}

// MARK: - MessageCategory 消息分类（官方频道专用）

/// 消息分类枚举（官方频道使用）
enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"   // 生存指南
    case news = "news"           // 游戏资讯
    case mission = "mission"     // 任务发布
    case alert = "alert"         // 紧急广播

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "游戏资讯"
        case .mission: return "任务发布"
        case .alert: return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news: return "newspaper.fill"
        case .mission: return "target"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - MessageMetadata 消息元数据

/// 消息元数据
struct MessageMetadata: Codable, Equatable {
    let deviceType: String?
    let category: String?  // 消息分类（官方频道使用）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - ChannelMessage 频道消息模型

/// 频道消息模型
struct ChannelMessage: Codable, Identifiable, Equatable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
    }

    /// 自定义解码（处理 PostGIS POINT 和日期格式）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)

        // 解析 PostGIS 位置（支持 WKT 字符串和 GeoJSON 对象）
        // 🐛 DEBUG: 打印解码过程
        if let rawValue = try? container.decode(String.self, forKey: .senderLocation) {
            print("🐛 [解码] sender_location 字符串: \(rawValue)")
            senderLocation = LocationPoint.fromPostGIS(rawValue)
            if senderLocation == nil {
                print("⚠️ [解码] WKT 解析失败")
            } else {
                print("✅ [解码] WKT 解析成功: \(senderLocation!)")
            }
        } else if let geoJSON = try? container.decode(GeoJSONPoint.self, forKey: .senderLocation) {
            print("🐛 [解码] GeoJSON: type=\(geoJSON.type), coords=\(geoJSON.coordinates)")
            senderLocation = LocationPoint(
                latitude: geoJSON.coordinates[1],
                longitude: geoJSON.coordinates[0]
            )
            print("✅ [解码] GeoJSON 解析成功: \(senderLocation!)")
        } else {
            print("⚠️ [解码] sender_location 为空或格式未知")
            senderLocation = nil
        }

        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // 多格式日期解析
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }

    /// 多格式日期解析
    private static func parseDate(_ string: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]

            return [f1, f2]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    /// 时间间隔描述
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    /// 设备类型
    var deviceType: String? {
        metadata?.deviceType
    }

    /// 发送者设备类型（用于距离过滤，Day 35）
    var senderDeviceType: DeviceType? {
        guard let deviceTypeString = metadata?.deviceType else { return nil }
        return DeviceType(rawValue: deviceTypeString)
    }

    /// 消息分类（官方频道使用，Day 36）
    var category: MessageCategory? {
        guard let categoryString = metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }

    /// 用于编码（发送时不需要完整编码）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(channelId, forKey: .channelId)
        try container.encodeIfPresent(senderId, forKey: .senderId)
        try container.encodeIfPresent(senderCallsign, forKey: .senderCallsign)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
    }
}

// MARK: - ChannelPreview 频道预览（消息中心使用 Day 36）

/// 频道预览模型（消息中心列表使用）
struct ChannelPreview: Codable, Identifiable {
    let channelId: UUID
    let channelName: String
    let channelType: String
    let channelCode: String
    let memberCount: Int
    let isMuted: Bool
    let unreadCount: Int
    let lastMessageContent: String?
    let lastMessageTime: Date?
    let lastMessageSender: String?

    var id: UUID { channelId }

    /// 是否为官方频道
    var isOfficial: Bool {
        channelType == "official"
    }

    /// 频道类型枚举
    var type: ChannelType {
        ChannelType(rawValue: channelType) ?? .public
    }

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case memberCount = "member_count"
        case isMuted = "is_muted"
        case unreadCount = "unread_count"
        case lastMessageContent = "last_message_content"
        case lastMessageTime = "last_message_time"
        case lastMessageSender = "last_message_sender"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        channelId = try container.decode(UUID.self, forKey: .channelId)
        channelName = try container.decode(String.self, forKey: .channelName)
        channelType = try container.decode(String.self, forKey: .channelType)
        channelCode = try container.decode(String.self, forKey: .channelCode)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        lastMessageContent = try container.decodeIfPresent(String.self, forKey: .lastMessageContent)
        lastMessageSender = try container.decodeIfPresent(String.self, forKey: .lastMessageSender)

        if let timeString = try? container.decode(String.self, forKey: .lastMessageTime) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: timeString) {
                lastMessageTime = date
            } else {
                // 尝试不带毫秒的格式
                let formatter2 = ISO8601DateFormatter()
                formatter2.formatOptions = [.withInternetDateTime]
                lastMessageTime = formatter2.date(from: timeString)
            }
        } else {
            lastMessageTime = nil
        }
    }

    /// 格式化时间显示
    var formattedTime: String {
        guard let time = lastMessageTime else { return "" }

        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(time) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        } else if calendar.isDateInYesterday(time) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: time)
        }
    }
}
