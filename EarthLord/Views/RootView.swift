//
//  RootView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

/// 根视图：控制启动页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if splashFinished {
                MainTabView()
                    .transition(.opacity)
            } else {
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
    }
}

#Preview {
    RootView()
}
