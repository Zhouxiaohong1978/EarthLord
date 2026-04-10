
//
//  ContentFilter.swift
//  EarthLord
//
//  内容关键词过滤工具
//

import Foundation

enum ContentFilter {

    // MARK: - Banned Keywords

    private static let bannedKeywords: [String] = [
        // 色情
        "色情", "裸体", "性爱", "做爱", "卖淫", "嫖娼", "援交",
        // 政治敏感
        "法轮功", "法轮大法", "六四", "天安门事件", "台独", "藏独", "新疆独立",
        // 暴力/仇恨
        "杀死", "杀人", "爆炸", "炸弹", "枪支", "毒品", "贩毒",
        // 诈骗/广告
        "加微信", "加QQ", "扫码", "点击链接", "免费领取", "私信我",
        // 英文脏话
        "fuck", "shit", "asshole", "bitch", "nigger", "faggot",
        // 中文脏话
        "傻逼", "草泥马", "妈的", "操你", "他妈", "狗日", "滚蛋",
    ]

    // MARK: - Filter

    struct FilterResult {
        let isClean: Bool
        let blockedKeyword: String?

        static let clean = FilterResult(isClean: true, blockedKeyword: nil)
    }

    static func check(_ text: String) -> FilterResult {
        let lowered = text.lowercased()
        for keyword in bannedKeywords {
            if lowered.contains(keyword.lowercased()) {
                return FilterResult(isClean: false, blockedKeyword: keyword)
            }
        }
        return .clean
    }
}
