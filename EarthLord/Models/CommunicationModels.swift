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
            return 50.0       // 收音机只能接收，范围较大
        case .walkieTalkie:
            return 5.0        // 对讲机短距离
        case .campRadio:
            return 50.0       // 营地电台中距离
        case .satellite:
            return Double.infinity  // 卫星电话全球
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
            return "50km (仅接收)"
        case .walkieTalkie:
            return "5km"
        case .campRadio:
            return "50km"
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
