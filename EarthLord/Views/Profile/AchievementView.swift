//
//  AchievementView.swift
//  EarthLord
//
//  成就系统主视图 - 横排章节卡片 + 下方展开详情

import SwiftUI

// MARK: - Main View

struct AchievementView: View {
    @StateObject private var manager = AchievementManager.shared
    @State private var selectedChapter: AchievementChapter = .zeroDay

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if manager.isLoading && manager.progressList.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().tint(ApocalypseTheme.primary)
                    Text(LanguageManager.shared.localizedString(for: "加载中..."))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        summaryCard
                        chapterSelector
                        chapterDetail
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await manager.load()
            // 默认选中当前进行中的章节
            selectedChapter = manager.currentChapter
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let lm = LanguageManager.shared
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lm.localizedString(for: "已解锁成就"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(manager.totalUnlocked)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("/ \(manager.totalCount)")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            let chapter = manager.currentChapter
            if manager.chapterStatuses[chapter] == .completed {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lm.localizedString(for: "全部章节已完成"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(ApocalypseTheme.info)
                        .font(.title2)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lm.localizedString(for: "当前章节"))
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    HStack(spacing: 5) {
                        Image(systemName: chapter.icon)
                            .font(.caption)
                        Text(LanguageManager.shared.localizedString(for: chapter.titleKey))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(chapter.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(chapter.color.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Chapter Selector（横排5张）

    private var chapterSelector: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 4 * 8) / 5
            HStack(spacing: 8) {
                ForEach(AchievementChapter.allCases) { chapter in
                    let status = manager.chapterStatuses[chapter] ?? .locked
                    let isSelected = selectedChapter == chapter
                    let items = manager.progressList.filter { $0.definition.chapter == chapter }
                    let unlockedCount = items.filter { $0.isUnlocked }.count

                    Button {
                        guard status != .locked else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedChapter = chapter
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSelected
                                          ? chapter.color.opacity(0.25)
                                          : chapter.color.opacity(0.08))
                                    .frame(width: 40, height: 40)

                                if status == .locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: chapter.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isSelected ? chapter.color : chapter.color.opacity(0.5))
                                }

                                // 完成印章
                                if status == .completed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(chapter.color)
                                        .background(Circle().fill(ApocalypseTheme.cardBackground).frame(width: 14, height: 14))
                                        .offset(x: 13, y: -13)
                                }
                            }

                            Text(LanguageManager.shared.localizedString(for: chapter.shortTitleKey))
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected
                                                 ? chapter.color
                                                 : (status == .locked ? .gray : ApocalypseTheme.textSecondary))

                            // 进度小标
                            if status == .active {
                                Text("\(unlockedCount)/\(items.count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? chapter.color : ApocalypseTheme.textSecondary)
                            } else if status == .completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(chapter.color)
                            } else {
                                Text("🔒")
                                    .font(.system(size: 10))
                            }
                        }
                        .frame(width: cardWidth)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected
                                      ? chapter.color.opacity(0.1)
                                      : ApocalypseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? chapter.color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                        .opacity(status == .locked ? 0.4 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(status == .locked)
                }
            }
        }
        .frame(height: 100)
    }

    // MARK: - Chapter Detail（选中章节的成就列表）

    private var chapterDetail: some View {
        let status = manager.chapterStatuses[selectedChapter] ?? .locked
        let items = manager.progressList.filter { $0.definition.chapter == selectedChapter }
        let unlockedCount = items.filter { $0.isUnlocked }.count
        let progressRatio = items.isEmpty ? 0.0 : Double(unlockedCount) / Double(items.count)

        return VStack(spacing: 0) {

            // ── 渐变标题区 ──
            ZStack(alignment: .leading) {
                // 渐变背景
                LinearGradient(
                    colors: [
                        selectedChapter.color.opacity(0.28),
                        selectedChapter.color.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        // 大图标
                        ZStack {
                            Circle()
                                .fill(selectedChapter.color.opacity(0.22))
                                .frame(width: 52, height: 52)
                            Image(systemName: selectedChapter.icon)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(selectedChapter.color)
                        }

                        // 标题 + 副标题
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LanguageManager.shared.localizedString(for: selectedChapter.titleKey))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Text(LanguageManager.shared.localizedString(for: selectedChapter.subtitleKey))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        // 完成状态
                        if status == .completed {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(selectedChapter.color)
                                .font(.title2)
                        } else {
                            Text("\(unlockedCount)/\(items.count)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(selectedChapter.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                    // 章节整体进度条
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(selectedChapter.color)
                                    .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                            }
                        }
                        .frame(height: 6)

                        let lm = LanguageManager.shared
                        let progressText = status == .completed
                            ? lm.localizedString(for: "全部完成")
                            : String(format: lm.localizedString(for: "achievement.progress.format"), Int(progressRatio * 100))
                        Text(progressText)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .clipShape(
                .rect(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 12
                )
            )

            Divider().background(Color.white.opacity(0.08))

            // ── 成就列表 ──
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, progress in
                    AchievementRowView(progress: progress, chapterColor: selectedChapter.color)
                    if index < items.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 64)
                    }
                }
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status == .completed ? selectedChapter.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedChapter)
    }
}

// MARK: - Achievement Row

struct AchievementRowView: View {
    let progress: AchievementProgress
    let chapterColor: Color

    private var iconColor: Color {
        progress.isUnlocked ? progress.definition.iconColor : .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(progress.isUnlocked
                          ? progress.definition.iconColor.opacity(0.18)
                          : Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                Image(systemName: progress.definition.icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(LanguageManager.shared.localizedString(for: progress.definition.titleKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(progress.isUnlocked
                                         ? ApocalypseTheme.textPrimary
                                         : ApocalypseTheme.textSecondary)
                    Spacer()
                    if progress.isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(progress.definition.iconColor)
                            .font(.system(size: 16))
                    } else {
                        Text("\(progress.formattedCurrent) / \(progress.formattedTarget)")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Text(LanguageManager.shared.localizedString(for: progress.definition.descriptionKey))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if !progress.isUnlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progress.definition.iconColor)
                                .frame(width: geo.size.width * CGFloat(progress.progressRatio), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(progress.isUnlocked ? 1.0 : 0.75)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AchievementView()
    }
}
