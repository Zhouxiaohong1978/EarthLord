//
//  ApocalypseTheme.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

/// 末日主题配色
enum ApocalypseTheme {
    // MARK: - 背景色
    static let background = Color(red: 0.08, green: 0.08, blue: 0.10)      // 主背景（近黑）
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.14)  // 卡片背景（深灰）
    static let tabBarBackground = Color(red: 0.95, green: 0.95, blue: 0.95) // Tab栏背景（浅色）

    // MARK: - 强调色
    static let primary = Color(red: 1.0, green: 0.4, blue: 0.1)            // 主题橙色
    static let primaryDark = Color(red: 0.8, green: 0.3, blue: 0.0)        // 深橙色

    // MARK: - 文字色
    static let textPrimary = Color.white                                    // 主文字
    static let textSecondary = Color(white: 0.6)                           // 次要文字
    static let textMuted = Color(white: 0.4)                               // 弱化文字

    // MARK: - 状态色
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)            // 成功/绿色
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)            // 警告/黄色
    static let danger = Color(red: 1.0, green: 0.3, blue: 0.3)             // 危险/红色
    static let info = Color(red: 0.3, green: 0.7, blue: 1.0)               // 信息/蓝色
}
