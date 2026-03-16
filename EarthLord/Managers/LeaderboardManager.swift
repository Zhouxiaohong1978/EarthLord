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
                return "\(Int(value)) 栋"
            }
        }
    }

    @Published var entries: [LeaderboardEntry] = []
    @Published var myEntry: LeaderboardEntry?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var currentUserId: String? { AuthManager.shared.currentUser?.id.uuidString }

    private init() {}

    // MARK: - Load

    func load(category: Category) async {
        isLoading = true
        errorMessage = nil
        entries = []
        myEntry = nil

        do {
            let aggregated: [(userId: String, value: Double)]

            switch category {
            case .distance:
                aggregated = try await fetchDistanceRanking()
            case .territory:
                aggregated = try await fetchTerritoryRanking()
            case .buildings:
                aggregated = try await fetchBuildingsRanking()
            }

            // 取前 20，查用户名
            let top20 = Array(aggregated.prefix(20))
            let userIds = top20.map { $0.userId }
            let names = try await fetchUsernames(userIds: userIds)

            var result: [LeaderboardEntry] = []
            for (index, item) in top20.enumerated() {
                let name = names[item.userId] ?? maskUserId(item.userId)
                let entry = LeaderboardEntry(
                    id: item.userId,
                    rank: index + 1,
                    displayName: name,
                    value: item.value,
                    isCurrentUser: item.userId == currentUserId
                )
                result.append(entry)
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

    private func fetchDistanceRanking() async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            let distanceWalked: Double
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case distanceWalked = "distance_walked"
            }
        }
        let records: [Record] = try await supabase
            .from("exploration_sessions")
            .select("user_id, distance_walked")
            .eq("status", value: "completed")
            .execute()
            .value

        var totals: [String: Double] = [:]
        for r in records {
            totals[r.userId, default: 0] += r.distanceWalked
        }
        return totals.map { ($0.key, $0.value) }
            .sorted { $0.value > $1.value }
    }

    private func fetchTerritoryRanking() async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            let area: Double
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case area
            }
        }
        let records: [Record] = try await supabase
            .from("territories")
            .select("user_id, area")
            .eq("is_active", value: true)
            .execute()
            .value

        var totals: [String: Double] = [:]
        for r in records {
            totals[r.userId, default: 0] += r.area
        }
        return totals.map { ($0.key, $0.value) }
            .sorted { $0.value > $1.value }
    }

    private func fetchBuildingsRanking() async throws -> [(userId: String, value: Double)] {
        struct Record: Codable {
            let userId: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }
        let records: [Record] = try await supabase
            .from("player_buildings")
            .select("user_id")
            .execute()
            .value

        var counts: [String: Double] = [:]
        for r in records {
            counts[r.userId, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }
            .sorted { $0.value > $1.value }
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
        let prefix = String(id.prefix(4))
        return "末日者_\(prefix)"
    }
}
