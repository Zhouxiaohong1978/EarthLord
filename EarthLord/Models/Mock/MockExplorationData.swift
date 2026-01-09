//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  包含：POI列表、背包物品、物品定义表、探索结果示例
//

import Foundation
import CoreLocation

// MARK: - POI 相关模型

/// POI 状态枚举
/// 用于标记兴趣点的探索状态
enum POIStatus: String, CaseIterable {
    case undiscovered = "未发现"       // 玩家尚未到达该位置
    case discovered = "已发现"         // 玩家已到达但未搜索
    case hasResources = "有物资"       // 已搜索且发现了物资
    case looted = "已搜空"             // 已搜索但物资已被拿走
    case dangerous = "危险区域"        // 特殊状态：有威胁
}

/// POI 类型枚举
/// 定义不同类型的兴趣点
enum POIType: String, CaseIterable {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case residential = "住宅区"
    case police = "警察局"
    case military = "军事设施"
}

/// POI 兴趣点模型
/// 代表地图上的一个可探索地点
struct POI: Identifiable {
    let id: UUID
    let name: String                    // 地点名称
    let type: POIType                   // 地点类型
    let coordinate: CLLocationCoordinate2D  // 地理坐标
    var status: POIStatus               // 当前状态
    let description: String             // 地点描述
    let estimatedResources: [String]    // 预计可能存在的资源类型
    let dangerLevel: Int                // 危险等级 1-5
    let lastVisited: Date?              // 最后访问时间

    init(
        id: UUID = UUID(),
        name: String,
        type: POIType,
        coordinate: CLLocationCoordinate2D,
        status: POIStatus,
        description: String,
        estimatedResources: [String] = [],
        dangerLevel: Int = 1,
        lastVisited: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.status = status
        self.description = description
        self.estimatedResources = estimatedResources
        self.dangerLevel = dangerLevel
        self.lastVisited = lastVisited
    }
}

// MARK: - 物品相关模型

/// 物品分类枚举
enum ItemCategory: String, CaseIterable {
    case water = "水类"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
    case clothing = "服装"
    case misc = "杂项"
}

/// 物品稀有度枚举
/// 影响物品的获取概率和价值
enum ItemRarity: String, CaseIterable {
    case common = "普通"           // 白色 - 随处可见
    case uncommon = "优良"         // 绿色 - 较为常见
    case rare = "稀有"             // 蓝色 - 需要特定地点
    case epic = "史诗"             // 紫色 - 非常罕见
    case legendary = "传说"        // 橙色 - 极其珍贵
}

/// 物品品质枚举
/// 某些物品有品质区分，影响效果
enum ItemQuality: String, CaseIterable {
    case broken = "破损"           // 效果大幅降低
    case worn = "磨损"             // 效果略微降低
    case normal = "普通"           // 正常效果
    case good = "良好"             // 效果略微提升
    case excellent = "优秀"        // 效果大幅提升
}

/// 物品定义模型
/// 记录每种物品的基础属性（静态数据）
struct ItemDefinition: Identifiable {
    let id: String                  // 物品唯一标识符
    let name: String                // 中文名称
    let category: ItemCategory      // 所属分类
    let weight: Double              // 单个重量（kg）
    let volume: Double              // 单个体积（升）
    let rarity: ItemRarity          // 稀有度
    let description: String         // 物品描述
    let stackable: Bool             // 是否可堆叠
    let maxStack: Int               // 最大堆叠数量
    let hasQuality: Bool            // 是否有品质区分

    init(
        id: String,
        name: String,
        category: ItemCategory,
        weight: Double,
        volume: Double,
        rarity: ItemRarity,
        description: String,
        stackable: Bool = true,
        maxStack: Int = 99,
        hasQuality: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.weight = weight
        self.volume = volume
        self.rarity = rarity
        self.description = description
        self.stackable = stackable
        self.maxStack = maxStack
        self.hasQuality = hasQuality
    }
}

/// 背包物品模型
/// 代表玩家背包中的一个物品实例
struct BackpackItem: Identifiable {
    let id: UUID
    let itemId: String              // 关联的物品定义ID
    var quantity: Int               // 数量
    let quality: ItemQuality?       // 品质（可选，部分物品无品质）
    let obtainedAt: Date            // 获得时间
    let obtainedFrom: String?       // 获得来源（如：废弃超市）

    init(
        id: UUID = UUID(),
        itemId: String,
        quantity: Int,
        quality: ItemQuality? = nil,
        obtainedAt: Date = Date(),
        obtainedFrom: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
        self.obtainedAt = obtainedAt
        self.obtainedFrom = obtainedFrom
    }

    /// 计算该物品的总重量
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }
}

// MARK: - 探索结果模型

/// 距离统计数据
struct DistanceStats {
    let current: Double             // 本次行走距离（米）
    let total: Double               // 累计行走距离（米）
    let rank: Int                   // 排名
}

/// 面积统计数据
struct AreaStats {
    let current: Double             // 本次探索面积（平方米）
    let total: Double               // 累计探索面积（平方米）
    let rank: Int                   // 排名
}

/// 获得的物品记录
struct ObtainedItem {
    let itemId: String              // 物品ID
    let quantity: Int               // 数量
    let quality: ItemQuality?       // 品质
}

/// 探索结果模型
/// 记录一次探索活动的完整结果
struct ExplorationResult: Identifiable {
    let id: UUID
    let startTime: Date             // 开始时间
    let endTime: Date               // 结束时间
    let duration: TimeInterval      // 探索时长（秒）
    let distanceStats: DistanceStats    // 距离统计
    let areaStats: AreaStats            // 面积统计
    let discoveredPOIs: [POI]           // 本次发现的POI
    let obtainedItems: [ObtainedItem]   // 获得的物品
    let experienceGained: Int           // 获得的经验值

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        distanceStats: DistanceStats,
        areaStats: AreaStats,
        discoveredPOIs: [POI] = [],
        obtainedItems: [ObtainedItem] = [],
        experienceGained: Int = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.distanceStats = distanceStats
        self.areaStats = areaStats
        self.discoveredPOIs = discoveredPOIs
        self.obtainedItems = obtainedItems
        self.experienceGained = experienceGained
    }
}

// MARK: - Mock 数据

/// 探索模块假数据容器
/// 包含所有用于测试和预览的静态数据
struct MockExplorationData {

    // MARK: - POI 列表假数据

    /// 5个不同状态的 POI 测试数据
    /// 用于地图展示、POI 列表等界面的测试
    static let poiList: [POI] = [
        // 废弃超市：已发现，有物资
        POI(
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            status: .hasResources,
            description: "一家被遗弃的大型超市，货架上还残留着一些物资。门窗破损，但相对安全。",
            estimatedResources: ["食物", "水", "生活用品"],
            dangerLevel: 2,
            lastVisited: Date().addingTimeInterval(-3600)  // 1小时前访问
        ),

        // 医院废墟：已发现，已被搜空
        POI(
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 31.2354, longitude: 121.4787),
            status: .looted,
            description: "曾经的市立医院，现在只剩下断壁残垣。已被多次搜刮，难以找到有价值的物资。",
            estimatedResources: ["医疗用品"],
            dangerLevel: 3,
            lastVisited: Date().addingTimeInterval(-86400)  // 1天前访问
        ),

        // 加油站：未发现
        POI(
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 31.2254, longitude: 121.4687),
            status: .undiscovered,
            description: "位于主干道旁的加油站，可能还有燃油储备。",
            estimatedResources: ["燃料", "工具", "零食"],
            dangerLevel: 2
        ),

        // 药店废墟：已发现，有物资
        POI(
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 31.2284, longitude: 121.4817),
            status: .hasResources,
            description: "社区药店的残骸，药柜里可能还有一些药品和医疗用品。",
            estimatedResources: ["药品", "绷带", "医疗工具"],
            dangerLevel: 1,
            lastVisited: Date().addingTimeInterval(-7200)  // 2小时前访问
        ),

        // 工厂废墟：未发现
        POI(
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 31.2404, longitude: 121.4637),
            status: .undiscovered,
            description: "废弃的制造工厂，可能有大量工业材料和工具。但结构不稳定，需要小心。",
            estimatedResources: ["废金属", "工具", "机械零件"],
            dangerLevel: 4
        )
    ]

    // MARK: - 物品定义表假数据

    /// 物品定义表
    /// 记录每种物品的基础属性，用于物品系统的初始化
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "一瓶干净的饮用水，生存必需品。",
            maxStack: 20,
            hasQuality: false
        ),

        // 食物
        ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "密封的罐头食品，保质期长，营养丰富。",
            maxStack: 15,
            hasQuality: true
        ),

        // 医疗
        ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.1,
            rarity: .common,
            description: "基础医疗用品，可以包扎轻微伤口。",
            maxStack: 30,
            hasQuality: true
        ),
        ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .uncommon,
            description: "常用药物，可以治疗感染和疾病。",
            maxStack: 20,
            hasQuality: true
        ),

        // 材料
        ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            description: "基础建造材料，可用于制作工具或搭建庇护所。",
            maxStack: 50,
            hasQuality: false
        ),
        ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 1.0,
            rarity: .common,
            description: "回收的金属碎片，可以熔炼或直接用于制作。",
            maxStack: 50,
            hasQuality: false
        ),

        // 工具
        ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "便携式照明工具，探索黑暗区域必备。",
            stackable: false,
            maxStack: 1,
            hasQuality: true
        ),
        ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            description: "坚固的尼龙绳，可用于攀爬、捆绑等多种用途。",
            maxStack: 10,
            hasQuality: true
        )
    ]

    // MARK: - 背包物品假数据

    /// 背包物品列表
    /// 模拟玩家当前携带的物品，用于背包界面测试
    static let backpackItems: [BackpackItem] = [
        // 矿泉水 x 5（无品质）
        BackpackItem(
            itemId: "water_bottle",
            quantity: 5,
            quality: nil,
            obtainedFrom: "废弃超市"
        ),

        // 罐头食品 x 3（良好品质）
        BackpackItem(
            itemId: "canned_food",
            quantity: 3,
            quality: .good,
            obtainedFrom: "废弃超市"
        ),

        // 绷带 x 8（普通品质）
        BackpackItem(
            itemId: "bandage",
            quantity: 8,
            quality: .normal,
            obtainedFrom: "药店废墟"
        ),

        // 药品 x 2（优秀品质）
        BackpackItem(
            itemId: "medicine",
            quantity: 2,
            quality: .excellent,
            obtainedFrom: "药店废墟"
        ),

        // 木材 x 12（无品质）
        BackpackItem(
            itemId: "wood",
            quantity: 12,
            obtainedFrom: "工厂废墟"
        ),

        // 废金属 x 7（无品质）
        BackpackItem(
            itemId: "scrap_metal",
            quantity: 7,
            obtainedFrom: "工厂废墟"
        ),

        // 手电筒 x 1（磨损品质）
        BackpackItem(
            itemId: "flashlight",
            quantity: 1,
            quality: .worn,
            obtainedFrom: "加油站"
        ),

        // 绳子 x 2（普通品质）
        BackpackItem(
            itemId: "rope",
            quantity: 2,
            quality: .normal,
            obtainedFrom: "仓库"
        )
    ]

    // MARK: - 探索结果假数据

    /// 探索结果示例
    /// 模拟一次完整的探索活动结果，用于结算界面测试
    static let sampleExplorationResult: ExplorationResult = {
        let startTime = Date().addingTimeInterval(-1800)  // 30分钟前开始
        let endTime = Date()

        return ExplorationResult(
            startTime: startTime,
            endTime: endTime,
            distanceStats: DistanceStats(
                current: 2500,          // 本次行走 2500 米
                total: 15000,           // 累计行走 15000 米
                rank: 42                // 排名第 42
            ),
            areaStats: AreaStats(
                current: 50000,         // 本次探索 5 万平方米
                total: 250000,          // 累计探索 25 万平方米
                rank: 38                // 排名第 38
            ),
            discoveredPOIs: [poiList[2]],  // 发现了加油站
            obtainedItems: [
                // 木材 x 5
                ObtainedItem(itemId: "wood", quantity: 5, quality: nil),
                // 矿泉水 x 3
                ObtainedItem(itemId: "water_bottle", quantity: 3, quality: nil),
                // 罐头 x 2
                ObtainedItem(itemId: "canned_food", quantity: 2, quality: .normal)
            ],
            experienceGained: 150       // 获得 150 经验值
        )
    }()

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品定义，如果未找到返回nil
    static func getItemDefinition(by itemId: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == itemId }
    }

    /// 计算背包总重量
    /// - Returns: 背包内所有物品的总重量（kg）
    static func calculateTotalBackpackWeight() -> Double {
        return backpackItems.reduce(0) { total, item in
            guard let definition = getItemDefinition(by: item.itemId) else { return total }
            return total + item.totalWeight(definition: definition)
        }
    }

    /// 按分类获取背包物品
    /// - Parameter category: 物品分类
    /// - Returns: 该分类下的所有背包物品
    static func getBackpackItems(by category: ItemCategory) -> [BackpackItem] {
        return backpackItems.filter { item in
            guard let definition = getItemDefinition(by: item.itemId) else { return false }
            return definition.category == category
        }
    }

    /// 按状态筛选POI
    /// - Parameter status: POI状态
    /// - Returns: 该状态的所有POI
    static func getPOIs(by status: POIStatus) -> [POI] {
        return poiList.filter { $0.status == status }
    }
}

// MARK: - 预览辅助

#if DEBUG
extension MockExplorationData {
    /// 用于 SwiftUI 预览的背包物品详细信息
    static var previewBackpackSummary: String {
        let totalWeight = calculateTotalBackpackWeight()
        let itemCount = backpackItems.reduce(0) { $0 + $1.quantity }
        return "背包物品：\(backpackItems.count)种 \(itemCount)件，总重量：\(String(format: "%.1f", totalWeight))kg"
    }
}
#endif
