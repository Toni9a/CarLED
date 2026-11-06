import SwiftUI

struct RemoteView: View {
    @Environment(LEDController.self) private var led
    @State private var mode: Mode = .colour
    @State private var showDevices = false

    enum Mode: String, CaseIterable { case colour = "Colour", white = "White", effects = "Effects" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DeviceCard { showDevices = true }
                    VStack(spacing: 16) {
                        PowerCard()
                        MusicCard()
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        switch mode {
                        case .colour: ColourPanel()
                        case .white: WhitePanel()
                        case .effects: EffectsPanel()
                        }
                    }
                    .disabled(!led.isConnected)
                    .opacity(led.isConnected ? 1 : 0.45)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .animation(.snappy, value: mode)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Car Light")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDevices = true } label: { Image(systemName: "antenna.radiowaves.left.and.right") }
                }
            }
            .sheet(isPresented: $showDevices) { DevicesSheet() }
        }
    }
}

private struct DeviceCard: View {
    @Environment(LEDController.self) private var led
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "lightbulb.led.wide.fill")
                        .font(.title2)
                        .foregroundStyle(led.isConnected ? currentTint : .secondary)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(led.deviceName ?? "No strip selected").font(.headline)
                        HStack(spacing: 6) {
                            if [.connecting, .searching, .starting].contains(led.status) { ProgressView().controlSize(.mini) }
                            Text(statusText).font(.subheadline).foregroundStyle(statusColour)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var currentTint: Color { led.effect == nil ? led.colour.color : Theme.accent }

    private var statusText: String {
        switch led.status {
        case .starting: "Starting Bluetooth…"
        case .bluetoothOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth permission needed (Settings › Car Light)"
        case .noDevice: "Tap to choose your LED strip"
        case .searching: "Searching…"
        case .connecting: "Waiting for strip… (is the car on?)"
        case .connected: "Connected"
        }
    }

    private var statusColour: Color {
        switch led.status {
        case .connected: .green
        case .bluetoothOff, .unauthorized: .red
        default: .secondary
        }
    }
}

private struct MusicCard: View {
    @State private var music = MusicMode.shared
    @State private var error: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(get: { music.isRunning }, set: toggle)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Music mode", systemImage: "music.note").font(.headline)
                        Text("Lights fade and pulse with the music. Siri: \u{201C}turn on Car Light music\u{201D}.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.accent)
                if music.isRunning {
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.08))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.accent).frame(width: max(6, geo.size.width * music.level))
                            }
                    }
                    .frame(height: 6)
                    .animation(.linear(duration: 0.08), value: music.level)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    private func toggle(_ on: Bool) {
        error = nil
        if on {
            Task {
                do { try await music.start(fromApp: true) } catch { self.error = error.localizedDescription }
            }
        } else {
            music.stop()
        }
    }
}

private struct PowerCard: View {
    @Environment(LEDController.self) private var led
    @State private var brightness: Double = 100

    var body: some View {
        Card {
            HStack(spacing: 18) {
                Button { led.togglePower() } label: {
                    Image(systemName: "power")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(led.isOn ? .black : Theme.accent)
                        .frame(width: 68, height: 68)
                        .background(led.isOn ? Theme.accent : Theme.accent.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact, trigger: led.isOn)
                .accessibilityLabel(led.isOn ? "Turn off" : "Turn on")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Brightness").font(.headline)
                        Spacer()
                        Text("\(Int(brightness))%").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $brightness, in: 1...100) { _ in }
                        .onChange(of: brightness) { _, v in led.setBrightness(v) }
                }
            }
        }
        .onAppear { brightness = led.brightness }
    }
}

private struct ColourPanel: View {
    @Environment(LEDController.self) private var led
    @State private var hue: Double = 0
    @State private var saturation: Double = 1

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Text("Colour").font(.title3.bold())
                ColourWheel(hue: $hue, saturation: $saturation)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .onChange(of: hue) { send() }
                    .onChange(of: saturation) { send() }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(LightColour.allCases) { c in
                        Button {
                            (hue, saturation) = c.rgb.hueSaturation
                            led.setColour(c.rgb, throttle: false)
                        } label: {
                            Circle().fill(c.rgb.color)
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(.white.opacity(led.colour == c.rgb && led.effect == nil ? 0.9 : 0), lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c.title)
                    }
                }
            }
        }
        .onAppear { (hue, saturation) = led.colour.hueSaturation }
    }

    private func send() {
        led.setColour(RGB(hue: hue, saturation: saturation))
    }
}

private struct WhitePanel: View {
    @Environment(LEDController.self) private var led
    @State private var warmth: Double = 0.5

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Text("White").font(.title3.bold())
                RoundedRectangle(cornerRadius: 16)
                    .fill(RGB.white(warmth: warmth).color)
                    .frame(height: 90)
                VStack(spacing: 6) {
                    Slider(value: $warmth, in: 0...1)
                        .tint(.white)
                        .onChange(of: warmth) { _, v in led.setColour(RGB.white(warmth: v)) }
                    HStack {
                        Text("Warm"); Spacer(); Text("Cool")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
