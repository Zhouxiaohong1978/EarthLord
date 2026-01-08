//
//  TerritoryManager.swift
//  EarthLord
//
//  Created on 2025/1/8.
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器
/// 负责领地数据的上传和拉取
final class TerritoryManager {

    // MARK: - 单例

    static let shared = TerritoryManager()

    private init() {}

    // MARK: - 私有属性

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: [["lat": x, "lon": y], ...] 格式的数组
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式（用于 PostGIS）
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: WKT 格式字符串，如 "SRID=4326;POLYGON((lon lat, ...))"
    /// - Note: WKT 格式是「经度在前，纬度在后」！
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return ""
        }

        // 确保多边形闭合（首尾相同）
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointsString = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(pointsString)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: (minLat, maxLat, minLon, maxLon) 元组
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else {
            return nil
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传方法

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 领地边界坐标点数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 圈地开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 获取当前用户 ID
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        // 验证坐标点数量
        guard coordinates.count >= 3 else {
            throw TerritoryError.insufficientPoints
        }

        // 准备数据
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // 构建上传数据
        let territoryData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "path": .array(pathJSON.map { point in
                .object([
                    "lat": .double(point["lat"] ?? 0),
                    "lon": .double(point["lon"] ?? 0)
                ])
            }),
            "polygon": .string(wktPolygon),
            "bbox_min_lat": .double(bbox.minLat),
            "bbox_max_lat": .double(bbox.maxLat),
            "bbox_min_lon": .double(bbox.minLon),
            "bbox_max_lon": .double(bbox.maxLon),
            "area": .double(area),
            "point_count": .integer(coordinates.count),
            "started_at": .string(startTime.ISO8601Format()),
            "completed_at": .string(Date().ISO8601Format()),
            "is_active": .bool(true)
        ]

        print("📤 开始上传领地数据...")
        print("   用户ID: \(userId.uuidString)")
        print("   点数: \(coordinates.count)")
        print("   面积: \(String(format: "%.2f", area)) 平方米")

        // 添加日志
        TerritoryLogger.shared.log("开始上传领地: \(coordinates.count)个点, \(Int(area))m²", type: .info)

        do {
            // 执行上传
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 拉取方法

    /// 加载所有激活的领地
    /// - Returns: Territory 数组
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 开始加载领地数据...")

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        print("✅ 加载完成，共 \(response.count) 个领地")

        return response
    }

    /// 加载当前用户的领地
    /// - Returns: Territory 数组
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        print("📥 开始加载我的领地...")

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value

        print("✅ 加载完成，共 \(response.count) 个领地")

        return response
    }

    /// 删除领地（软删除，设置 is_active = false）
    /// - Parameter territoryId: 领地 ID
    func deleteTerritory(id: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        print("🗑️ 开始删除领地: \(id)")

        try await supabase
            .from("territories")
            .update(["is_active": false])
            .eq("id", value: id)
            .eq("user_id", value: userId.uuidString)  // 确保只能删除自己的
            .execute()

        print("✅ 领地已删除")
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case insufficientPoints
    case invalidCoordinates
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .insufficientPoints:
            return "坐标点数量不足（至少需要3个点）"
        case .invalidCoordinates:
            return "无效的坐标数据"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        }
    }
}
