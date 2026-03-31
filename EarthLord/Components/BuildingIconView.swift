//
//  BuildingIconView.swift
//  EarthLord
//
//  建筑图标视图 - 自动判断 SF Symbol 或自定义图片资产
//  图标名含 "." → SF Symbol；不含 "." → Assets.xcassets 自定义图片
//

import SwiftUI

struct BuildingIconView: View {
    let iconName: String
    let size: CGFloat
    let tintColor: Color

    var body: some View {
        if iconName.contains(".") {
            // SF Symbol
            Image(systemName: iconName)
                .font(.system(size: size))
                .foregroundColor(tintColor)
        } else {
            // 自定义图片资产
            Image(iconName)
                .resizable()
                .scaledToFill()
                .frame(width: size * 1.8, height: size * 1.8)
                .clipShape(Circle())
        }
    }
}
