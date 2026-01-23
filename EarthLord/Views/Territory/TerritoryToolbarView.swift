//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地详情页悬浮工具栏组件
//

import SwiftUI

/// 领地详情页悬浮工具栏
struct TerritoryToolbarView: View {
    /// 关闭回调
    var onDismiss: () -> Void
    /// 打开建筑浏览器回调
    var onBuildingBrowser: () -> Void
    /// 信息面板显示状态
    @Binding var showInfoPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            toolbarButton(icon: "xmark", action: onDismiss)

            Spacer()

            // 建造按钮
            toolbarButton(icon: "hammer.fill", color: ApocalypseTheme.primary, action: onBuildingBrowser)

            // 信息面板切换按钮
            toolbarButton(
                icon: showInfoPanel ? "chevron.down" : "chevron.up",
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showInfoPanel.toggle()
                    }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 工具栏按钮
    private func toolbarButton(icon: String, color: Color = ApocalypseTheme.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(ApocalypseTheme.background.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                onDismiss: {},
                onBuildingBrowser: {},
                showInfoPanel: .constant(true)
            )

            Spacer()
        }
    }
}
