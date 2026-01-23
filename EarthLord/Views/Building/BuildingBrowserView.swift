//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览器 - 分类筛选 + 建筑卡片网格
//

import SwiftUI

/// 建筑浏览器视图
struct BuildingBrowserView: View {
    /// 关闭回调
    var onDismiss: () -> Void
    /// 开始建造回调
    var onStartConstruction: (BuildingTemplate) -> Void

    /// 建筑管理器
    @StateObject private var buildingManager = BuildingManager.shared

    /// 当前选中的分类（nil 表示全部）
    @State private var selectedCategory: BuildingCategory?

    /// 选中的建筑详情
    @State private var selectedTemplate: BuildingTemplate?

    /// 筛选后的建筑模板
    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.buildingTemplates.filter { $0.category == category }
        }
        return buildingManager.buildingTemplates
    }

    /// 网格列配置
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryFilterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()
                    .background(ApocalypseTheme.textMuted)

                // 建筑网格
                if filteredTemplates.isEmpty {
                    emptyView
                } else {
                    buildingGrid
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(String(localized: "建筑浏览"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            // 确保模板已加载
            if buildingManager.buildingTemplates.isEmpty {
                buildingManager.loadTemplates()
            }
        }
        .sheet(item: $selectedTemplate) { template in
            BuildingDetailView(
                template: template,
                onDismiss: { selectedTemplate = nil },
                onStartConstruction: { tmpl in
                    selectedTemplate = nil
                    onStartConstruction(tmpl)
                }
            )
        }
    }

    // MARK: - 子视图

    /// 分类筛选栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部按钮
                AllCategoryButton(isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 各分类按钮
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.displayName,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    /// 建筑网格
    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredTemplates) { template in
                    BuildingCard(template: template) {
                        selectedTemplate = template
                    }
                }
            }
            .padding(16)
        }
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(String(localized: "暂无建筑"))
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    BuildingBrowserView(
        onDismiss: {},
        onStartConstruction: { template in
            print("开始建造: \(template.name)")
        }
    )
}
