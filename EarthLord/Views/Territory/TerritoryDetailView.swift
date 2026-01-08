//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 显示领地地图预览和详细信息
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    // MARK: - State

    /// 是否显示删除确认
    @State private var showDeleteConfirm = false

    /// 是否显示功能敬请期待提示
    @State private var showComingSoon = false

    /// 敬请期待的功能名称
    @State private var comingSoonFeature = ""

    /// 环境变量 - 用于返回
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 地图预览
                mapPreview
                    .frame(height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                // 基本信息卡片
                infoCard
                    .padding(.horizontal, 16)

                // 操作按钮区域
                actionButtons
                    .padding(.horizontal, 16)

                // 危险操作区域
                dangerZone
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(territory.name ?? "领地详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("删除领地", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("确定要删除这块 \(String(format: "%.0f", territory.area)) m² 的领地吗？此操作无法撤销。")
        }
        .alert("敬请期待", isPresented: $showComingSoon) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("\(comingSoonFeature)功能正在开发中，敬请期待！")
        }
    }

    // MARK: - 地图预览

    private var mapPreview: some View {
        TerritoryMapPreview(territory: territory)
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("基本信息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 面积
            InfoRow(
                icon: "square.dashed",
                label: "领地面积",
                value: String(format: "%.0f m²", territory.area)
            )

            // 点数
            if let pointCount = territory.pointCount {
                InfoRow(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    label: "边界点数",
                    value: "\(pointCount) 个"
                )
            }

            // 创建时间
            if let createdAt = territory.createdAt {
                InfoRow(
                    icon: "calendar",
                    label: "占领时间",
                    value: formatDate(createdAt)
                )
            }

            // 圈地开始时间
            if let startedAt = territory.startedAt {
                InfoRow(
                    icon: "play.circle",
                    label: "开始圈地",
                    value: formatDate(startedAt)
                )
            }

            // 圈地完成时间
            if let completedAt = territory.completedAt {
                InfoRow(
                    icon: "checkmark.circle",
                    label: "完成圈地",
                    value: formatDate(completedAt)
                )
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("领地管理")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 按钮网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // 重命名
                ActionButton(
                    icon: "pencil",
                    title: "重命名",
                    color: ApocalypseTheme.info
                ) {
                    comingSoonFeature = "重命名"
                    showComingSoon = true
                }

                // 建筑系统
                ActionButton(
                    icon: "building.2",
                    title: "建筑",
                    color: ApocalypseTheme.success
                ) {
                    comingSoonFeature = "建筑系统"
                    showComingSoon = true
                }

                // 领地交易
                ActionButton(
                    icon: "arrow.left.arrow.right",
                    title: "交易",
                    color: ApocalypseTheme.warning
                ) {
                    comingSoonFeature = "领地交易"
                    showComingSoon = true
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 危险操作区域

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("危险操作")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.danger)

            // 删除按钮
            Button(action: {
                showDeleteConfirm = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除领地")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.danger)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 辅助方法

    /// 格式化日期字符串
    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        if let date = isoFormatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }

        return isoString
    }
}

// MARK: - 信息行组件

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            // 图标和标签
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 值
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - 操作按钮组件

private struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - 地图预览组件

private struct TerritoryMapPreview: UIViewRepresentable {
    let territory: Territory

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.isUserInteractionEnabled = false // 禁用交互，仅作预览
        mapView.showsUserLocation = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 移除旧的覆盖层
        mapView.removeOverlays(mapView.overlays)

        // 获取坐标
        var coordinates = territory.toCoordinates()
        guard coordinates.count >= 3 else { return }

        // 坐标转换（WGS-84 → GCJ-02）
        coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

        // 添加多边形
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)

        // 计算边界并设置地图区域
        let boundingRect = polygon.boundingMapRect
        let paddedRect = boundingRect.insetBy(dx: -boundingRect.size.width * 0.2,
                                               dy: -boundingRect.size.height * 0.2)
        mapView.setVisibleMapRect(paddedRect, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryDetailView(
            territory: Territory(
                id: "preview-id",
                userId: "user-id",
                name: "我的第一块领地",
                path: [
                    ["lat": 31.2304, "lon": 121.4737],
                    ["lat": 31.2314, "lon": 121.4737],
                    ["lat": 31.2314, "lon": 121.4747],
                    ["lat": 31.2304, "lon": 121.4747]
                ],
                area: 1500,
                pointCount: 25,
                isActive: true,
                startedAt: "2025-01-08T10:00:00Z",
                completedAt: "2025-01-08T10:15:00Z",
                createdAt: "2025-01-08T10:15:30Z"
            )
        )
    }
}
