//
//  PlayerDensityService.swift
//  EarthLord
//
//  玩家密度查询服务 - 查询附近玩家数量并计算密度等级
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 玩家密度查询服务
@MainActor
final class PlayerDensityService: ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerDensityService()

    // MARK: - Constants

    /// 默认查询半径（米）
    private let defaultRadius: Int = 1000

    // MARK: - Published Properties

    /// 最近的密度查询结果
    @Published var currentDensity: PlayerDensityResult?

    /// 是否正在查询
    @Published var isQuerying: Bool = false

    // MARK: - Private Properties

    /// 日志器
    private let logger = ExplorationLogger.shared

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Initialization

    private init() {
        logger.log("PlayerDensityService 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 查询附近玩家数量
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radius: 查询半径（米），默认1000米
    /// - Returns: 密度查询结果
    func queryNearbyPlayers(
        latitude: Double,
        longitude: Double,
        radius: Int? = nil
    ) async throws -> PlayerDensityResult {
        guard AuthManager.shared.isAuthenticated else {
            throw DensityQueryError.notAuthenticated
        }

        isQuerying = true
        defer { isQuerying = false }

        let queryRadius = radius ?? defaultRadius

        logger.log("查询附近玩家: 中心(\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))，半径 \(queryRadius)m", type: .info)

        // 调用 RPC 函数查询
        let response: Int = try await supabase.rpc(
            "count_nearby_players",
            params: [
                "p_latitude": latitude,
                "p_longitude": longitude,
                "p_radius_meters": Double(queryRadius)
            ]
        ).execute().value

        let result = PlayerDensityResult(
            count: response,
            latitude: latitude,
            longitude: longitude
        )

        // 更新当前密度
        currentDensity = result

        logger.log("附近玩家数量: \(response)人，密度等级: \(result.densityLevel.rawValue)", type: .success)

        return result
    }

    /// 使用当前位置查询附近玩家
    func queryNearbyPlayersAtCurrentLocation() async throws -> PlayerDensityResult {
        guard let coordinate = LocationManager.shared.userLocation else {
            throw DensityQueryError.locationNotAvailable
        }

        return try await queryNearbyPlayers(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

/// 密度查询错误
enum DensityQueryError: LocalizedError {
    case notAuthenticated
    case locationNotAvailable
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .locationNotAvailable:
            return "无法获取当前位置"
        case .queryFailed(let message):
            return "查询失败: \(message)"
        }
    }
}
