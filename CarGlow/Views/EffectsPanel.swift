import SwiftUI

struct EffectsPanel: View {
    @Environment(LEDController.self) private var led
    @State private var speed: Double = 50

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                Text("Effects").font(.title3.bold())
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Speed", systemImage: "speedometer").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(speed))%").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $speed, in: 0...100)
                        .onChange(of: speed) { _, v in led.setSpeed(v) }
                }
                ForEach(EffectGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.rawValue).font(.headline).foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(LightEffect.allCases.filter { $0.group == group }) { e in
                                EffectTile(effect: e, selected: led.effect == e) { led.setEffect(e) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { speed = led.speed }
    }
}

private struct EffectTile: View {
    let effect: LightEffect
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: effect.group.symbol)
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                HStack(spacing: 4) {
                    ForEach(Array(effect.swatches.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: 4).fill(c).frame(height: 16)
                    }
                }
                Text(effect.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(selected ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
