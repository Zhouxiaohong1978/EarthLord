//
//  PTTCallView.swift
//  EarthLord
//
//  呼叫中心 - Day 36 实现
//

import SwiftUI

struct PTTCallView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "phone.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("呼叫中心")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("Day 36 实现")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    PTTCallView()
}
