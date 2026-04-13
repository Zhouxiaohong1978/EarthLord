//
//  AdminBroadcastView.swift
//  EarthLord
//
//  管理员官方消息发布入口（仅晓红账号可见）
//

import SwiftUI
import Supabase

// MARK: - 定时消息模型

struct ScheduledMessage: Identifiable, Decodable {
    let id: UUID
    let content: String
    let contentEn: String
    let category: String
    let scheduledAt: Date
    let isPublished: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content, category
        case contentEn = "content_en"
        case scheduledAt = "scheduled_at"
        case isPublished = "is_published"
        case createdAt = "created_at"
    }
}

// MARK: - AdminBroadcastView

struct AdminBroadcastView: View {
    @Environment(\.dismiss) private var dismiss
    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    @State private var contentZh = ""
    @State private var contentEn = ""
    @State private var selectedCategory = "news"
    @State private var isScheduled = false
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var scheduledMessages: [ScheduledMessage] = []
    @State private var isLoadingList = false

    private let categories: [(key: String, zh: String, en: String, icon: String, color: Color)] = [
        ("news",     "游戏资讯", "Game News",       "newspaper.fill",                    .blue),
        ("survival", "生存指南", "Survival Guide",  "leaf.fill",                          .green),
        ("mission",  "任务发布", "Missions",        "target",                             .orange),
        ("alert",    "紧急广播", "Emergency Alert", "exclamationmark.triangle.fill",      .red),
    ]

    private var selectedCategoryInfo: (key: String, zh: String, en: String, icon: String, color: Color) {
        categories.first { $0.key == selectedCategory } ?? categories[0]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 分类选择
                        categoryPicker

                        // 内容输入
                        contentSection

                        // 发布时间
                        scheduleSection

                        // 发布按钮
                        publishButton

                        // 定时消息列表
                        scheduledListSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布官方消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .task { await loadScheduled() }
        }
    }

    // MARK: - 分类选择

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(categories, id: \.key) { cat in
                    Button(action: { selectedCategory = cat.key }) {
                        VStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14))
                            Text(cat.zh)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedCategory == cat.key ? .white : cat.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedCategory == cat.key ? cat.color : cat.color.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - 内容输入

    private var contentSection: some View {
        VStack(spacing: 12) {
            inputField(
                title: "中文内容",
                placeholder: "输入中文消息内容...",
                text: $contentZh,
                icon: "character.chinese"
            )
            inputField(
                title: "English Content",
                placeholder: "Enter English message content...",
                text: $contentEn,
                icon: "character"
            )
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption).fontWeight(.semibold)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)

            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 定时设置

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isScheduled) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                    Text("定时发布")
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .tint(ApocalypseTheme.primary)

            if isScheduled {
                DatePicker(
                    "发布时间",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        VStack(spacing: 8) {
            if let err = error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
            }

            Button(action: publish) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isScheduled ? "clock.badge.fill" : "megaphone.fill")
                    }
                    Text(isScheduled ? "加入定时队列" : "立即发布")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canPublish ? selectedCategoryInfo.color : ApocalypseTheme.textMuted)
                )
            }
            .disabled(!canPublish || isSubmitting)
        }
    }

    private var canPublish: Bool {
        !contentZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contentEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 定时消息列表

    private var scheduledListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("待发队列")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Button(action: { Task { await loadScheduled() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if isLoadingList {
                ProgressView().tint(ApocalypseTheme.primary).frame(maxWidth: .infinity)
            } else if scheduledMessages.isEmpty {
                Text("暂无定时消息")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(scheduledMessages) { msg in
                    scheduledRow(msg)
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func scheduledRow(_ msg: ScheduledMessage) -> some View {
        let cat = categories.first { $0.key == msg.category }
        return HStack(spacing: 10) {
            Image(systemName: cat?.icon ?? "megaphone.fill")
                .font(.system(size: 14))
                .foregroundColor(cat?.color ?? ApocalypseTheme.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(msg.content)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(2)
                Text(formatDate(msg.scheduledAt))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Button(action: { Task { await cancel(msg.id) } }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.danger.opacity(0.7))
            }
        }
        .padding(10)
        .background(ApocalypseTheme.background)
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func publish() {
        let zh = contentZh.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = contentEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !zh.isEmpty, !en.isEmpty else { return }

        isSubmitting = true
        error = nil

        Task {
            do {
                struct Params: Encodable {
                    let p_content: String
                    let p_content_en: String
                    let p_category: String
                    let p_scheduled_at: String?
                }

                let scheduledAt: String? = isScheduled
                    ? ISO8601DateFormatter().string(from: scheduledDate)
                    : nil

                let params = Params(
                    p_content: zh,
                    p_content_en: en,
                    p_category: selectedCategory,
                    p_scheduled_at: scheduledAt
                )

                let _: UUID = try await supabase
                    .rpc("admin_publish_message", params: params)
                    .execute()
                    .value

                await MainActor.run {
                    contentZh = ""
                    contentEn = ""
                    isScheduled = false
                    isSubmitting = false
                }
                await loadScheduled()
            } catch {
                await MainActor.run {
                    self.error = "发布失败：\(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }

    private func cancel(_ id: UUID) async {
        do {
            try await supabase
                .rpc("admin_cancel_scheduled_message", params: ["p_id": id.uuidString])
                .execute()
            await loadScheduled()
        } catch {
            print("取消失败: \(error)")
        }
    }

    private func loadScheduled() async {
        isLoadingList = true
        do {
            let msgs: [ScheduledMessage] = try await supabase
                .rpc("admin_get_scheduled_messages")
                .execute()
                .value
            await MainActor.run {
                self.scheduledMessages = msgs.filter { !$0.isPublished }
                isLoadingList = false
            }
        } catch {
            await MainActor.run { isLoadingList = false }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}
