//
//  CoordinateConverter.swift
//  EarthLord
//
//  WGS-84 → GCJ-02 坐标转换工具
//  解决中国地图 GPS 偏移问题
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter 坐标转换器

/// 中国 GPS 坐标转换工具
/// WGS-84（国际标准 GPS）→ GCJ-02（中国加密坐标）
enum CoordinateConverter {

    // MARK: - 常量

    /// 地球长半轴 (米)
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = Double.pi

    // MARK: - Public Methods

    /// WGS-84 转 GCJ-02
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，不进行转换
        if isOutOfChina(coordinate) {
            return coordinate
        }

        var dLat = transformLat(coordinate.longitude - 105.0, coordinate.latitude - 35.0)
        var dLon = transformLon(coordinate.longitude - 105.0, coordinate.latitude - 35.0)

        let radLat = coordinate.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let mgLat = coordinate.latitude + dLat
        let mgLon = coordinate.longitude + dLon

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }

    /// 批量转换坐标数组
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断是否在中国境外
    private static func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 中国大致经纬度范围
        // 纬度：3.86 ~ 53.55
        // 经度：73.66 ~ 135.05
        if coordinate.longitude < 72.004 || coordinate.longitude > 137.8347 {
            return true
        }
        if coordinate.latitude < 0.8293 || coordinate.latitude > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度偏移计算
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return result
    }

    /// 经度偏移计算
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return result
    }
}
