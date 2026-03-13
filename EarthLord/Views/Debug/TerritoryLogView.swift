//
//  TerritoryLogView.swift
//  EarthLord
//
//  圈地日志查看器（支持崩溃后恢复）
//

import SwiftUI

struct TerritoryLogView: View {

    @ObservedObject private var logger = TerritoryLogger.shared
    @State private var autoScroll = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日志内容
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logger.logs) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: logger.logs.count) { _ in
                        if autoScroll, let last = logger.logs.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // 底部工具栏
                HStack {
                    Text("\(logger.logs.count) 条")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    Toggle("自动滚动", isOn: $autoScroll)
                        .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.primary))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("圈地日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareLog) {
                            Label("分享日志文件", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive, action: { logger.clear() }) {
                            Label("清空日志", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTime(entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize()

            Text("[\(entry.type.rawValue)]")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(entry.type.color)
                .fixedSize()

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(entry.type.color)
                .lineLimit(nil)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func shareLog() {
        let content = logger.export()
        let fileName = "territory_log_\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? content.write(to: url, atomically: true, encoding: .utf8)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

#Preview {
    TerritoryLogView()
}
