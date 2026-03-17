//
//  AchievementManager.swift
//  EarthLord
//
//  成就数据管理器 - 从 Supabase 读取用户统计并计算成就进度

import Foundation
import SwiftUI
import Supabase

// MARK: - Chapter Status

enum ChapterStatus {
    case locked, active, completed
}

// MARK: - Stats

struct AchievementStats {
    var totalDistance: Double = 0
    var totalArea: Double = 0
    var buildingCount: Int = 0
    var explorationCount: Int = 0
    var territoryCount: Int = 0
}

// MARK: - Manager

@MainActor
final class AchievementManager: ObservableObject {

    static let shared = AchievementManager()

    @Published var progressList: [AchievementProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var userId: String? { AuthManager.shared.currentUser?.id.uuidString.lowercased() }

    private init() {}

    // MARK: - Computed

    var chapterStatuses: [AchievementChapter: ChapterStatus] {
        var statuses: [AchievementChapter: ChapterStatus] = [:]
        for chapter in AchievementChapter.allCases {
            let items = progressList.filter { $0.definition.chapter == chapter }
            let allComplete = !items.isEmpty && items.allSatisfy { $0.isUnlocked }

            let previousComplete: Bool
            if chapter == .zeroDay {
                previousComplete = true
            } else {
                let prev = AchievementChapter(rawValue: chapter.rawValue - 1)!
                previousComplete = statuses[prev] == .completed
            }

            if allComplete {
                statuses[chapter] = .completed
            } else if previousComplete {
                statuses[chapter] = .active
            } else {
                statuses[chapter] = .locked
            }
        }
        return statuses
    }

    var currentChapter: AchievementChapter {
        let statuses = chapterStatuses
        for chapter in AchievementChapter.allCases {
            if statuses[chapter] != .completed { return chapter }
        }
        return .legend
    }

    var totalUnlocked: Int { progressList.filter { $0.isUnlocked }.count }
    var totalCount: Int { AchievementDefinition.catalog.count }

    // MARK: - Load

    func load() async {
        guard let uid = userId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let dist = fetchTotalDistance(userId: uid)
            async let area = fetchTotalArea(userId: uid)
            async let bldg = fetchBuildingCount(userId: uid)
            async let expl = fetchExplorationCount(userId: uid)
            async let terr = fetchTerritoryCount(userId: uid)

            let stats = AchievementStats(
                totalDistance: try await dist,
                totalArea: try await area,
                buildingCount: try await bldg,
                explorationCount: try await expl,
                territoryCount: try await terr
            )

            progressList = AchievementDefinition.catalog.map { def in
                let (current, unlocked) = evaluate(def.condition, stats: stats)
                return AchievementProgress(definition: def, currentValue: current, isUnlocked: unlocked)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Evaluate

    private func evaluate(_ condition: AchievementCondition, stats: AchievementStats) -> (Double, Bool) {
        switch condition {
        case .firstLogin:
            return (1, true)
        case .explorationCount(let n):
            return (Double(stats.explorationCount), stats.explorationCount >= n)
        case .totalDistance(let d):
            return (stats.totalDistance, stats.totalDistance >= d)
        case .territoryCount(let n):
            return (Double(stats.territoryCount), stats.territoryCount >= n)
        case .totalTerritoryArea(let a):
            return (stats.totalArea, stats.totalArea >= a)
        case .buildingCount(let n):
            return (Double(stats.buildingCount), stats.buildingCount >= n)
        }
    }

    // MARK: - Queries

    private func fetchTotalDistance(userId: String) async throws -> Double {
        struct Row: Codable {
            let distanceWalked: Double
            enum CodingKeys: String, CodingKey { case distanceWalked = "distance_walked" }
        }
        let rows: [Row] = try await supabase
            .from("exploration_sessions")
            .select("distance_walked")
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute().value
        return rows.reduce(0) { $0 + $1.distanceWalked }
    }

    private func fetchTotalArea(userId: String) async throws -> Double {
        struct Row: Codable { let area: Double }
        let rows: [Row] = try await supabase
            .from("territories")
            .select("area")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute().value
        return rows.reduce(0) { $0 + $1.area }
    }

    private func fetchBuildingCount(userId: String) async throws -> Int {
        struct Row: Codable { let id: String }
        let rows: [Row] = try await supabase
            .from("player_buildings")
            .select("id")
            .eq("user_id", value: userId)
            .execute().value
        return rows.count
    }

    private func fetchExplorationCount(userId: String) async throws -> Int {
        struct Row: Codable { let id: String }
        let rows: [Row] = try await supabase
            .from("exploration_sessions")
            .select("id")
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute().value
        return rows.count
    }

    private func fetchTerritoryCount(userId: String) async throws -> Int {
        struct Row: Codable { let id: String }
        let rows: [Row] = try await supabase
            .from("territories")
            .select("id")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute().value
        return rows.count
    }
}
