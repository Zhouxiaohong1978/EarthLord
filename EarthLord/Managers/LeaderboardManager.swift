//
//  LeaderboardManager.swift
//  EarthLord
//
//  排行榜数据管理器 - 探索距离 / 领地面积 / 建筑数量
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Models

struct LeaderboardEntry: Identifiable {
    let id: String          // userId
    let rank: Int
    let displayName: String
    let value: Double
    let isCurrentUser: Bool
}

// MARK: - Manager

@MainActor
final class LeaderboardManager: ObservableObject {

    static let shared = LeaderboardManager()

    enum Category: String, CaseIterable {
        case distance  = "探索距离"
        case territory = "领地面积"
        case buildings = "建筑数量"

        var icon: String {
            switch self {
            case .distance:  return "figure.walk"
            case .territory: return "map.fill"
            case .buildings: return "building.2.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .distance:  return ApocalypseTheme.info
            case .territory: return ApocalypseTheme.success
            case .buildings: return ApocalypseTheme.primary
            }
        }

        func formattedValue(_ value: Double) -> String {
            switch self {
            case .distance:
                if value >= 1000 { return String(format: "%.1f km", value / 1000) }
                return String(format: "%.0f m", value)
            case .territory:
                if value >= 1_000_000 { return String(format: "%.2f km²", value / 1_000_000) }
                return String(format: "%.0f m²", value)
            case .buildings:
                return "\(Int(value)) 个"
            }
        }
    }

    enum TimeFilter: String, CaseIterable {
        case today = "今日"
        case week  = "本周"
        case all   = "总榜"

        var startDate: Date? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .today: return cal.startOfDay(for: now)
            case .week:  return cal.dateInterval(of: .weekOfYear, for: now)?.start
            case .all:   return nil
            }
        }
    }

    @Published var entries: [LeaderboardEntry] = []
    @Published var myEntry: LeaderboardEntry?
    @Published var totalPlayerCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var currentUserId: String? { AuthManager.shared.currentUser?.id.uuidString.lowercased() }

    private init() {}

    // MARK: - Load

    func load(category: Category, timeFilter: TimeFilter) async {
        isLoading = true
        errorMessage = nil
        entries = []
        myEntry = nil
        totalPlayerCount = 0

        do {
            let aggregated: [(userId: String, value: Double)]

            switch category {
            case .distance:
                aggregated = try await fetchDistanceRanking(timeFilter: timeFilter)
            case .territory:
                aggregated = try await fetchTerritoryRanking(timeFilter: timeFilter)
            case .buildings:
                aggregated = try await fetchBuildingsRanking(timeFilter: timeFilter)
            }

            totalPlayerCount = aggregated.count
            let top20 = Array(aggregated.prefix(20))
            let userIds = top20.map { $0.userId }
            let names = try await fetchUsernames(userIds: userIds)

            var result: [LeaderboardEntry] = []
            for (index, item) in top20.enumerated() {
                let name = names[item.userId] ?? maskUserId(item.userId)
                result.append(LeaderboardEntry(
                    id: item.userId,
                    rank: index + 1,
                    displayName: name,
                    value: item.value,
                    isCurrentUser: item.userId == currentUserId
                ))
            }
            entries = result

            // 当前用户排名（可能不在前20）
            if let uid = currentUserId {
                if let existing = result.first(where: { $0.id == uid }) {
                    myEntry = existing
                } else if let myData = aggregated.first(where: { $0.userId == uid }) {
                    let myRank = (aggregated.firstIndex(where: { $0.userId == uid }) ?? 0) + 1
                    let myName = (try? await fetchUsernames(userIds: [uid]))?[uid] ?? maskUserId(uid)
                    myEntry = LeaderboardEntry(
                        id: uid,
                        rank: myRank,
                        displayName: myName,
                        value: myData.value,
                        isCurrentUser: true
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Queries

    private func fetchDistanceRanking(timeFilter: TimeFilter) async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            let distanceWalked: Double
            let startedAt: String?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case distanceWalked = "distance_walked"
                case startedAt = "started_at"
            }
        }

        var query = supabase
            .from("exploration_sessions")
            .select("user_id, distance_walked, started_at")
            .eq("status", value: "completed")

        if let start = timeFilter.startDate {
            query = query.gte("started_at", value: ISO8601DateFormatter().string(from: start))
        }

        let records: [Record] = try await query.execute().value

        var totals: [String: Double] = [:]
        for r in records { totals[r.userId, default: 0] += r.distanceWalked }
        return totals.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    private func fetchTerritoryRanking(timeFilter: TimeFilter) async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            let area: Double
            let completedAt: String?
            let createdAt: String?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case area
                case completedAt = "completed_at"
                case createdAt = "created_at"
            }
        }

        var query = supabase
            .from("territories")
            .select("user_id, area, completed_at, created_at")
            .eq("is_active", value: true)

        if let start = timeFilter.startDate {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: start))
        }

        let records: [Record] = try await query.execute().value

        var totals: [String: Double] = [:]
        for r in records { totals[r.userId, default: 0] += r.area }
        return totals.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    private func fetchBuildingsRanking(timeFilter: TimeFilter) async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            let createdAt: String?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case createdAt = "created_at"
            }
        }

        var query = supabase
            .from("player_buildings")
            .select("user_id, created_at")

        if let start = timeFilter.startDate {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: start))
        }

        let records: [Record] = try await query.execute().value

        var counts: [String: Double] = [:]
        for r in records { counts[r.userId, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    private func fetchUsernames(userIds: [String]) async throws -> [String: String] {
        guard !userIds.isEmpty else { return [:] }
        struct Profile: Codable {
            let id: String
            let username: String?
            let callsign: String?
        }
        let profiles: [Profile] = try await supabase
            .from("profiles")
            .select("id, username, callsign")
            .in("id", values: userIds)
            .execute()
            .value

        var result: [String: String] = [:]
        for p in profiles {
            result[p.id] = p.username ?? p.callsign ?? maskUserId(p.id)
        }
        return result
    }

    private func maskUserId(_ id: String) -> String {
        "末日者_\(String(id.prefix(4)))"
    }
}
