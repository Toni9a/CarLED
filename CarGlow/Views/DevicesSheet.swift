import SwiftUI

struct DevicesSheet: View {
    @Environment(LEDController.self) private var led
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let name = led.deviceName {
                    Section("Current strip") {
                        LabeledContent(name, value: led.isConnected ? "Connected" : "Not connected")
                        Button("Forget this strip", role: .destructive) { led.forgetDevice() }
                    }
                }
                Section {
                    ForEach(led.discovered) { d in
                        Button {
                            led.choose(d)
                            dismiss()
                        } label: {
                            HStack {
                                Text(d.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "cellularbars", variableValue: signal(d.rssi))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Nearby")
                        if led.isScanning { ProgressView().controlSize(.mini) }
                    }
                } footer: {
                    Text("Close Lumo Remote or any other LED app first. The strip can only talk to one phone app at a time.")
                }
                Section {
                    if led.activity.isEmpty {
                        Text("Nothing yet").foregroundStyle(.secondary)
                    }
                    ForEach(Array(led.activity.prefix(40).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Activity")
                        Spacer()
                        Button("Clear") { led.clearLog() }.font(.caption)
                    }
                }
            }
            .navigationTitle("LED Strips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(led.isScanning ? "Scanning…" : "Scan") { led.startScan() }.disabled(led.isScanning)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onAppear { led.startScan() }
            .onDisappear { led.stopScan() }
        }
        .presentationDetents([.medium, .large])
    }

    private func signal(_ rssi: Int) -> Double { min(1, max(0, Double(rssi + 100) / 50)) }
}
