//
//  ContentView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("Developed by [zhouxiaohong]")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
    }
}
#Preview {
    ContentView()
}
