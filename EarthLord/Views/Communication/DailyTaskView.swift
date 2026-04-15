//
//  DailyTaskView.swift
//  EarthLord
//
//  每日任务 UI - 嵌入官方频道「任务发布」分类
//

import SwiftUI

// MARK: - DailyTaskView

struct DailyTaskView: View {
    @StateObject private var taskManager = DailyTaskManager.shared
    @State private var claimingType: DailyTaskType?
    @State private var showError = false

    private var completedCount: Int { taskManager.tasks.filter(\.isCompleted).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                progressBanner

                if taskManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .padding(.top, 40)
                } else {
                    ForEach(taskManager.tasks) { task in
                        DailyTaskCard(
                            task: task,
                            isClaiming: claimingType == task.type
                        ) {
                            await claim(task)
                        }
                    }
                }

                footerNote
            }
            .padding(16)
        }
        .background(ApocalypseTheme.background)
        .task { await taskManager.refresh() }
        .refreshable { await taskManager.refresh() }
        .alert(String(localized: "领取失败"), isPresented: $showError) {
            Button(String(localized: "确定"), role: .cancel) {}
        } message: {
            Text(taskManager.claimError ?? "")
        }
    }

    // MARK: - Progress Banner

    private var progressBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "今日进度"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(String(format: String(localized: "%d / 3 已完成"), completedCount))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(String(format: String(localized: "本周主题：%@"), WeeklyRewardRotation.current.theme))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(ApocalypseTheme.textMuted.opacity(0.25), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: min(CGFloat(completedCount) / 3.0, 1.0))
                    .stroke(ApocalypseTheme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: completedCount)
                Text("\(completedCount)/3")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var footerNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(String(localized: "每日 00:00 自动刷新"))
                .font(.caption2)
        }
        .foregroundColor(ApocalypseTheme.textMuted)
        .padding(.top, 4)
    }

    // MARK: - Claim

    private func claim(_ task: DailyTask) async {
        claimingType = task.type
        do {
            try await taskManager.claimReward(for: task)
        } catch {
            taskManager.claimError = error.localizedDescription
            showError = true
        }
        claimingType = nil
    }
}

// MARK: - DailyTaskCard

struct DailyTaskCard: View {
    let task: DailyTask
    let isClaiming: Bool
    let onClaim: () async -> Void

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBgColor)
                    .frame(width: 46, height: 46)
                Image(systemName: task.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // 任务信息
            VStack(alignment: .leading, spacing: 4) {
                Text(task.type.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(task.type.taskDescription)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10))
                    Text(task.type.rewardDescription)
                        .font(.caption2)
                }
                .foregroundColor(ApocalypseTheme.primary.opacity(0.85))
            }

            Spacer()

            // 状态/按钮
            statusView
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusView: some View {
        if task.isRewardClaimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.success)
        } else if task.isCompleted {
            Button {
                Task { await onClaim() }
            } label: {
                Group {
                    if isClaiming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(String(localized: "领取"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 60)
                .padding(.vertical, 7)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
            .disabled(isClaiming)
        } else {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    private var iconBgColor: Color {
        task.isRewardClaimed ? ApocalypseTheme.success.opacity(0.15) :
        task.isCompleted     ? ApocalypseTheme.primary.opacity(0.2) :
                               ApocalypseTheme.textMuted.opacity(0.1)
    }

    private var iconColor: Color {
        task.isRewardClaimed ? ApocalypseTheme.success :
        task.isCompleted     ? ApocalypseTheme.primary :
                               ApocalypseTheme.textMuted
    }

    private var borderColor: Color {
        task.isRewardClaimed ? ApocalypseTheme.success.opacity(0.3) :
        task.isCompleted     ? ApocalypseTheme.primary.opacity(0.4) :
                               Color.clear
    }
}

#Preview {
    NavigationStack {
        DailyTaskView()
    }
}
