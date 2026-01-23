//
//  MoreTabView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    MoreTabView()
}
