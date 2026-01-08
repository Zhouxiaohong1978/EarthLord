//
//  Territory.swift
//  EarthLord
//
//  Created on 2025/1/8.
//

import Foundation
import CoreLocation

/// 领地数据模型
/// 用于解析数据库返回的领地数据
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // 可选，数据库允许为空
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let startedAt: String?
    let completedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
