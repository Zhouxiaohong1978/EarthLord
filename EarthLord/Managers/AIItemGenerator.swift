//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI物品生成器 - 调用Edge Function生成独特物品
//

import Foundation
import Supabase

// MARK: - AIItemGeneratorError

/// AI物品生成错误类型
enum AIItemGeneratorError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case invalidResponse
    case aiGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .invalidResponse:
            return "AI响应格式错误"
        case .aiGenerationFailed(let message):
            return "AI生成失败: \(message)"
        }
    }
}

// MARK: - Request/Response Models

/// AI物品生成请求
struct GenerateItemRequest: Codable {
    let poiName: String
    let poiType: String
    let dangerLevel: Int
    let itemCount: Int
}

/// AI物品生成响应
struct GenerateItemResponse: Codable {
    let success: Bool
    let items: [AIItemData]?
    let error: String?
    let timestamp: String?
}

/// AI生成的物品数据
struct AIItemData: Codable {
    let name: String
    let story: String
    let category: String
    let rarity: String
}

// MARK: - AIItemGenerator

/// AI物品生成器（单例）
@MainActor
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private let logger = ExplorationLogger.shared

    private init() {
        logger.log("AIItemGenerator 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 为POI生成AI物品
    /// - Parameters:
    ///   - poi: 目标POI
    ///   - itemCount: 生成物品数量（默认1-3随机）
    /// - Returns: AI生成的物品列表
    func generateItems(for poi: POI, itemCount: Int? = nil) async throws -> [AIGeneratedItem] {
        guard AuthManager.shared.currentUser != nil else {
            throw AIItemGeneratorError.notAuthenticated
        }

        let count = itemCount ?? Int.random(in: 1...3)

        logger.log("🤖 开始AI物品生成: \(poi.name), 危险等级: \(poi.dangerLevel), 数量: \(count)", type: .info)

        // 构建请求
        let request = GenerateItemRequest(
            poiName: poi.name,
            poiType: poi.type.rawValue,
            dangerLevel: poi.dangerLevel,
            itemCount: count
        )

        do {
            // 调用 Edge Function
            let response: GenerateItemResponse = try await supabase.functions
                .invoke(
                    "generate-ai-item",
                    options: FunctionInvokeOptions(body: request)
                )

            // 检查响应
            guard response.success, let items = response.items else {
                let errorMsg = response.error ?? "未知错误"
                logger.logError("AI生成失败: \(errorMsg)")
                throw AIItemGeneratorError.aiGenerationFailed(errorMsg)
            }

            // 转换为 AIGeneratedItem
            let generatedItems = items.map { item in
                AIGeneratedItem(
                    name: item.name,
                    story: item.story,
                    category: item.category,
                    rarity: item.rarity,
                    quantity: 1,
                    quality: generateRandomQuality()
                )
            }

            logger.log("✅ AI生成成功: \(generatedItems.count) 件物品", type: .success)
            for item in generatedItems {
                logger.log("  - [\(item.rarity)] \(item.name)", type: .info)
            }

            return generatedItems

        } catch let error as AIItemGeneratorError {
            throw error
        } catch {
            logger.logError("AI物品生成网络错误", error: error)
            throw AIItemGeneratorError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// 生成随机品质
    private func generateRandomQuality() -> ItemQuality {
        let randomValue = Double.random(in: 0...1)
        if randomValue < 0.1 {
            return .broken
        } else if randomValue < 0.25 {
            return .worn
        } else if randomValue < 0.60 {
            return .normal
        } else if randomValue < 0.85 {
            return .good
        } else {
            return .excellent
        }
    }
}
