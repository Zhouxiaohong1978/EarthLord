//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/26.
//

import SwiftUI
import Supabase

// MARK: - Supabase 客户端单例
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://bckczjqrrsuhfzudrkin.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJja2N6anFycnN1aGZ6dWRya2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU0MzU0ODEsImV4cCI6MjA4MTAxMTQ4MX0.MR0ZfnhulWqIeseXOp4tEOJMFQlJ4-LW6agJnBRqoSg"
        )
    }
}

// MARK: - 连接状态枚举
enum ConnectionStatus {
    case idle
    case testing
    case success
    case failure
}

struct SupabaseTestView: View {
    @State private var status: ConnectionStatus = .idle
    @State private var logText: String = "点击按钮开始测试连接..."

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 状态图标
                statusIcon
                    .frame(width: 80, height: 80)

                // 调试日志文本框
                ScrollView {
                    Text(logText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)

                // 测试连接按钮
                Button(action: testConnection) {
                    HStack {
                        if status == .testing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(status == .testing ? "测试中..." : "测试连接")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(status == .testing ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(status == .testing)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标视图
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "network")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
        case .testing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(2.0)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.success)
        case .failure:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.danger)
        }
    }

    // MARK: - 测试连接逻辑
    private func testConnection() {
        status = .testing
        logText = "[\(timestamp)] 开始测试连接...\n"
        logText += "[\(timestamp)] URL: bckczjqrrsuhfzudrkin.supabase.co\n"
        logText += "[\(timestamp)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await SupabaseManager.shared.client
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（不太可能），也算成功
                await MainActor.run {
                    status = .success
                    logText += "[\(timestamp)] ✅ 连接成功（查询返回成功）\n"
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    // MARK: - 错误处理
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        logText += "[\(timestamp)] 收到响应，正在分析...\n"
        logText += "[\(timestamp)] 错误详情: \(errorString)\n"

        // 判断错误类型
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("schema cache") ||
           errorString.contains("PostgrestError") ||
           (errorString.contains("relation") && errorString.contains("does not exist")) {
            // PostgreSQL REST API 错误，说明服务器已响应
            status = .success
            logText += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            logText += "[\(timestamp)] 说明：收到 PostgrestError 表示服务器正常工作，只是查询的表不存在。\n"
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") ||
                  errorString.contains("network") {
            // 网络或 URL 错误
            status = .failure
            logText += "[\(timestamp)] ❌ 连接失败：URL 错误或无网络\n"
            logText += "[\(timestamp)] 请检查网络连接和 Supabase URL 配置\n"
        } else {
            // 其他错误
            status = .failure
            logText += "[\(timestamp)] ❌ 未知错误\n"
            logText += "[\(timestamp)] 错误信息: \(error.localizedDescription)\n"
        }
    }

    // MARK: - 时间戳
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空响应模型
private struct EmptyResponse: Decodable {}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
