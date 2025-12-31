//
//  LanguageManager.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/31.
//

import Foundation
import SwiftUI
import Combine

/// 应用内语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"        // 跟随系统
    case chinese = "zh-Hans"      // 简体中文
    case english = "en"           // English

    var id: String { rawValue }

    /// 显示名称（用当前语言显示）
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("跟随系统", comment: "")
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 获取实际使用的语言代码
    var languageCode: String? {
        switch self {
        case .system:
            return Locale.preferredLanguages.first?.components(separatedBy: "-").first
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器
/// 负责管理应用内语言切换，支持持久化存储
@MainActor
final class LanguageManager: ObservableObject {

    // MARK: - 单例

    static let shared = LanguageManager()

    // MARK: - 发布属性

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage

    /// 当前实际使用的语言代码
    @Published var currentLocale: String

    // MARK: - 私有属性

    private let userDefaultsKey = "app_language"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        let savedLanguage: AppLanguage
        if let savedLanguageString = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguageString) {
            savedLanguage = language
        } else {
            // 默认跟随系统
            savedLanguage = .system
        }

        // 初始化存储属性
        self.currentLanguage = savedLanguage
        self.currentLocale = savedLanguage.languageCode ?? "zh-Hans"

        print("🌐 LanguageManager 初始化")
        print("   当前语言: \(currentLanguage.displayName)")
        print("   语言代码: \(currentLocale)")

        // 监听语言变化
        $currentLanguage
            .sink { [weak self] language in
                self?.saveLanguage()
                self?.updateLocale()
            }
            .store(in: &cancellables)
    }

    // MARK: - 公开方法

    /// 切换语言
    /// - Parameter language: 目标语言
    func changeLanguage(to language: AppLanguage) {
        print("🌐 切换语言: \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 键值
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(for key: String, comment: String = "") -> String {
        // 如果是跟随系统，使用系统默认行为
        if currentLanguage == .system {
            return NSLocalizedString(key, comment: comment)
        }

        // 否则使用指定语言
        guard let languageCode = currentLanguage.languageCode,
              let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath) else {
            return NSLocalizedString(key, comment: comment)
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - 私有方法

    /// 保存语言设置到 UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        print("💾 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新语言代码
    private func updateLocale() {
        if let languageCode = currentLanguage.languageCode {
            // 延迟一帧更新，确保 SwiftUI 能够正确响应变化
            DispatchQueue.main.async {
                self.currentLocale = languageCode
                print("🔄 语言代码已更新: \(languageCode)")
            }
        }
    }
}

/// 自定义 Text 修饰符，用于本地化
struct LocalizedText: View {
    let key: String
    @ObservedObject private var languageManager = LanguageManager.shared

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(languageManager.localizedString(for: key))
    }
}
