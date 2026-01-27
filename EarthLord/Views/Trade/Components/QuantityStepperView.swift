//
//  QuantityStepperView.swift
//  EarthLord
//
//  数量调节器组件
//  [-] [数量] [+] 水平布局
//

import SwiftUI

struct QuantityStepperView: View {
    @Binding var value: Int
    let minValue: Int
    let maxValue: Int

    init(value: Binding<Int>, min: Int = 1, max: Int = 99) {
        self._value = value
        self.minValue = min
        self.maxValue = max
    }

    var body: some View {
        HStack(spacing: 0) {
            // 减少按钮
            Button {
                if value > minValue {
                    value -= 1
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(value > minValue ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.background)
                    )
            }
            .disabled(value <= minValue)

            // 数量显示
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(minWidth: 40)

            // 增加按钮
            Button {
                if value < maxValue {
                    value += 1
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(value < maxValue ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.background)
                    )
            }
            .disabled(value >= maxValue)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var quantity = 5

        var body: some View {
            VStack(spacing: 20) {
                QuantityStepperView(value: $quantity, min: 1, max: 10)

                Text("当前数量: \(quantity)")
                    .foregroundColor(.white)
            }
            .padding()
            .background(ApocalypseTheme.background)
        }
    }

    return PreviewWrapper()
}
