//
//  ContentView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Text("Developed by [zhouxiaohong]")
                    .font(.headline)
                    .foregroundColor(.blue)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}
#Preview {
    ContentView()
}
