//
//  LeaderboardView.swift
//  EarthLord
//
//  排行榜视图 - 探索距离 / 领地面积 / 建筑数量
//

import SwiftUI

struct LeaderboardView: View {

    @StateObject private var manager = LeaderboardManager.shared
    @State private var selectedCategory: LeaderboardManager.Category = .distance
    @State private var selectedTime: LeaderboardManager.TimeFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // 标题居中
            Text("排行榜")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            // 时间筛选
            HStack(spacing: 0) {
                ForEach(LeaderboardManager.TimeFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedTime = filter
                        Task { await manager.load(category: selectedCategory, timeFilter: filter) }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTime == filter ? .semibold : .regular)
                            .foregroundColor(selectedTime == filter ? .white : ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                selectedTime == filter
                                    ? RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.info)
                                    : RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                            )
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground))

            // 分类切换
            HStack(spacing: 6) {
                ForEach(LeaderboardManager.Category.allCases, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                        Task { await manager.load(category: cat, timeFilter: selectedTime) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon).font(.caption2)
                            Text(cat.rawValue)
                                .font(.caption)
                                .fontWeight(selectedCategory == cat ? .semibold : .regular)
                        }
                        .foregroundColor(selectedCategory == cat ? .white : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategory == cat
                                ? RoundedRectangle(cornerRadius: 8).fill(cat.iconColor)
                                : RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                        )
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground))

            // 内容区
            if manager.isLoading {
                loadingView
            } else if let error = manager.errorMessage {
                errorView(error)
            } else if manager.entries.isEmpty {
                emptyView
            } else {
                entriesList
            }
        }
        .onAppear {
            Task { await manager.load(category: selectedCategory, timeFilter: selectedTime) }
        }
    }

    // MARK: - 榜单列表

    private var entriesList: some View {
        VStack(spacing: 8) {
            // 我的排名 / 总玩家数
            if let my = manager.myEntry {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("我的排名：第 \(my.rank) 名 / 共 \(manager.totalPlayerCount) 名玩家")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)
            }

            VStack(spacing: 1) {
                ForEach(manager.entries) { entry in
                    entryRow(entry)
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)

            // 当前用户（不在前20时固定显示）
            if let my = manager.myEntry, !manager.entries.contains(where: { $0.id == my.id }) {
                VStack(spacing: 0) {
                    Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
                    entryRow(my)
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    private func entryRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            rankBadge(entry.rank).frame(width: 32)

            Text(entry.displayName)
                .font(.callout)
                .fontWeight(entry.isCurrentUser ? .semibold : .regular)
                .foregroundColor(entry.isCurrentUser ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(selectedCategory.formattedValue(entry.value))
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(entry.isCurrentUser ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(entry.isCurrentUser ? ApocalypseTheme.primary.opacity(0.08) : Color.clear)
    }

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        switch rank {
        case 1:
            Image(systemName: "medal.fill").foregroundColor(Color(hex: "#FFD700")).font(.callout)
        case 2:
            Image(systemName: "medal.fill").foregroundColor(Color(hex: "#C0C0C0")).font(.callout)
        case 3:
            Image(systemName: "medal.fill").foregroundColor(Color(hex: "#CD7F32")).font(.callout)
        default:
            Text("\(rank)")
                .font(.caption).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - 状态视图

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                ProgressView().tint(ApocalypseTheme.primary)
                Text("加载中...").font(.caption).foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2).foregroundColor(ApocalypseTheme.warning)
            Text(message).font(.caption).foregroundColor(ApocalypseTheme.textSecondary).multilineTextAlignment(.center)
            Button("重试") { Task { await manager.load(category: selectedCategory, timeFilter: selectedTime) } }
                .font(.callout).foregroundColor(ApocalypseTheme.primary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.title2).foregroundColor(ApocalypseTheme.textMuted)
            Text("暂无数据").font(.callout).foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background.ignoresSafeArea()
        ScrollView { LeaderboardView().padding(.horizontal, 16) }
    }
}
