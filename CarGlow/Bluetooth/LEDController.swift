import Foundation
import CoreBluetooth
import Observation

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    var rssi: Int
}

enum LightError: LocalizedError {
    case bluetoothUnavailable
    case noDevice
    case timedOut

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: "Bluetooth is off or Car Light isn't allowed to use it."
        case .noDevice: "No LED strip has been set up yet. Open Car Light to pick one."
        case .timedOut: "Couldn't reach the lights. Make sure the car is on."
        }
    }
}

/// Owns the Bluetooth connection to the LED controller and the current light state.
/// Shared by the app UI, Siri/Shortcuts intents and CarPlay.
@MainActor
@Observable
final class LEDController: NSObject {
    static let shared = LEDController()

    enum Status: Equatable {
        case starting, bluetoothOff, unauthorized, noDevice, searching, connecting, connected
    }

    // MARK: Public state

    private(set) var status: Status = .starting
    private(set) var discovered: [DiscoveredDevice] = []
    private(set) var isScanning = false

    private(set) var deviceName: String? {
        didSet { defaults.set(deviceName, forKey: Keys.deviceName) }
    }
    private(set) var isOn: Bool { didSet { defaults.set(isOn, forKey: Keys.isOn) } }
    private(set) var brightness: Double { didSet { defaults.set(brightness, forKey: Keys.brightness) } }
    private(set) var colour: RGB { didSet { saveCodable(colour, Keys.colour) } }
    private(set) var effect: LightEffect? { didSet { saveCodable(effect, Keys.effect) } }
    private(set) var speed: Double { didSet { defaults.set(speed, forKey: Keys.speed) } }

    var isConnected: Bool { status == .connected }

    // MARK: Private

    private enum Keys {
        static let deviceID = "deviceID", deviceName = "deviceName", isOn = "isOn",
                   brightness = "brightness", colour = "colour", effect = "effect", speed = "speed"
    }

    private let defaults = UserDefaults.standard
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var savedDeviceID: UUID? {
        get { defaults.string(forKey: Keys.deviceID).flatMap(UUID.init) }
        set { defaults.set(newValue?.uuidString, forKey: Keys.deviceID) }
    }

    // Coalesces rapid writes (dragging sliders / colour wheel) to one per interval per command type.
    private var pending: [String: Data] = [:]
    private var flushScheduled: Set<String> = []
    /// Avoid flooding the log while dragging sliders.
    private var isThrottledLogging: Bool { !flushScheduled.isEmpty }

    private static let preferredServices = [CBUUID(string: "FFF0"), CBUUID(string: "FFE0"), CBUUID(string: "FFD5")]
    private static let preferredCharacteristics = [CBUUID(string: "FFF3"), CBUUID(string: "FFE1"), CBUUID(string: "FFD9")]

    override private init() {
        let d = UserDefaults.standard
        isOn = d.object(forKey: Keys.isOn) as? Bool ?? true
        brightness = d.object(forKey: Keys.brightness) as? Double ?? 100
        speed = d.object(forKey: Keys.speed) as? Double ?? 50
        deviceName = d.string(forKey: Keys.deviceName)
        colour = Self.loadCodable(RGB.self, Keys.colour, d) ?? RGB(r: 255, g: 90, b: 0)
        effect = Self.loadCodable(LightEffect.self, Keys.effect, d) ?? nil
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.toniesan.carglow.central"]
        )
    }

    // MARK: Commands

    func setPower(_ on: Bool) {
        isOn = on
        write(on ? ELKProtocol.powerOn : ELKProtocol.powerOff, key: "power", throttle: false)
    }

    func togglePower() { setPower(!isOn) }

    func setBrightness(_ value: Double) {
        brightness = max(1, min(100, value))
        write(ELKProtocol.brightness(Int(brightness)), key: "brightness")
    }

    func setColour(_ rgb: RGB, throttle: Bool = true) {
        colour = rgb
        effect = nil
        if !isOn { setPower(true) }
        write(ELKProtocol.colour(rgb), key: "colour", throttle: throttle)
    }

    func setEffect(_ e: LightEffect) {
        effect = e
        if !isOn { setPower(true) }
        write(ELKProtocol.effect(e), key: "effect", throttle: false)
        write(ELKProtocol.speed(Int(speed)), key: "speed", throttle: false)
    }

    func setSpeed(_ value: Double) {
        speed = max(0, min(100, value))
        write(ELKProtocol.speed(Int(speed)), key: "speed")
    }

    /// Used by Siri / Shortcuts / CarPlay: connects if needed (waiting up to `timeout`), then runs `action`.
    func perform(timeout: TimeInterval = 6, _ action: (LEDController) -> Void) async throws {
        try await ensureConnected(timeout: timeout)
        action(self)
        // Give CoreBluetooth a moment to flush the write before the intent process may be suspended.
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Siri/Shortcuts entry point. Never throws, so Siri always speaks a real reply.
    func runForSiri(success: String, _ action: (LEDController) -> Void) async -> String {
        log("Siri: \(success)")
        do {
            try await perform(action)
            return success
        } catch {
            log("Siri failed: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    // MARK: Activity log

    private(set) var activity: [String] = UserDefaults.standard.stringArray(forKey: "activity") ?? []

    func log(_ message: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        activity.insert("\(stamp)  \(message)", at: 0)
        if activity.count > 60 { activity.removeLast(activity.count - 60) }
        defaults.set(activity, forKey: "activity")
    }

    func clearLog() {
        activity.removeAll()
        defaults.set(activity, forKey: "activity")
    }

    // MARK: Device management

    func startScan() {
        guard central.state == .poweredOn else { return }
        discovered.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.stopScan()
        }
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        if status == .searching { status = peripheral == nil ? .noDevice : .connecting }
    }

    func choose(_ device: DiscoveredDevice) {
        stopScan()
        if let p = peripheral, p.identifier != device.id { central.cancelPeripheralConnection(p) }
        savedDeviceID = device.id
        deviceName = device.name
        guard let p = central.retrievePeripherals(withIdentifiers: [device.id]).first else { return }
        connect(p)
    }

    func forgetDevice() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        writeCharacteristic = nil
        savedDeviceID = nil
        deviceName = nil
        status = .noDevice
    }

    // MARK: Internals

    private func ensureConnected(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch status {
            case .connected where writeCharacteristic != nil:
                return
            case .bluetoothOff, .unauthorized:
                throw LightError.bluetoothUnavailable
            case .noDevice where savedDeviceID == nil:
                throw LightError.noDevice
            default:
                if central.state == .poweredOn { reconnectIfNeeded() }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw LightError.timedOut
    }

    private func reconnectIfNeeded() {
        guard central.state == .poweredOn, let id = savedDeviceID else { return }
        if let p = peripheral, p.state == .connected || p.state == .connecting { return }
        if let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(p)
        }
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        status = .connecting
        // No timeout: iOS keeps this pending and connects as soon as the strip powers up (e.g. car starts).
        central.connect(p, options: nil)
    }

    private func write(_ data: Data, key: String, throttle: Bool = true) {
        guard throttle else {
            pending[key] = nil
            send(data)
            return
        }
        pending[key] = data
        guard !flushScheduled.contains(key) else { return }
        flushScheduled.insert(key)
        if let d = pending.removeValue(forKey: key) { send(d) }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self else { return }
            self.flushScheduled.remove(key)
            if let d = self.pending.removeValue(forKey: key) { self.send(d) }
        }
    }

    private func send(_ data: Data) {
        guard let p = peripheral, p.state == .connected, let c = writeCharacteristic else {
            log("Not connected, command dropped")
            reconnectIfNeeded()
            return
        }
        if !isThrottledLogging { log("Sent " + data.map { String(format: "%02X", $0) }.joined(separator: " ")) }
        let type: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(data, for: c, type: type)
    }

    private static func isLikelyLEDController(_ name: String) -> Bool {
        let n = name.uppercased()
        return ["ELK", "BLEDOM", "BLEDDM", "LEDBLE", "MELK", "DUOCO", "TRIONES", "QHM"].contains { n.contains($0) }
    }

    private func saveCodable<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, _ key: String, _ d: UserDefaults) -> T? {
        d.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

// MARK: - CBCentralManagerDelegate

extension LEDController: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            log("Bluetooth state \(central.state.rawValue)")
            switch central.state {
            case .poweredOn:
                if let p = peripheral, p.state == .connected {
                    status = .connected
                } else if savedDeviceID != nil {
                    reconnectIfNeeded()
                    if peripheral == nil { status = .noDevice }
                } else {
                    status = .searching
                    startScan()
                }
            case .unauthorized: status = .unauthorized
            case .poweredOff, .unsupported: status = .bluetoothOff
            default: break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        MainActor.assumeIsolated {
            if let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first {
                peripheral = restored
                restored.delegate = self
                if restored.state == .connected { restored.discoverServices(nil) }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
            guard let name, !name.isEmpty else { return }
            let device = DiscoveredDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
            if let i = discovered.firstIndex(where: { $0.id == device.id }) {
                discovered[i].rssi = device.rssi
            } else {
                discovered.append(device)
            }
            discovered.sort {
                let a = Self.isLikelyLEDController($0.name), b = Self.isLikelyLEDController($1.name)
                return a != b ? a : $0.rssi > $1.rssi
            }
            // First run: automatically pick the first LED controller we see.
            if savedDeviceID == nil, Self.isLikelyLEDController(name) {
                choose(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            log("Connected to \(peripheral.name ?? "strip"), discovering services")
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            log("Connect failed: \(error?.localizedDescription ?? "unknown")")
            writeCharacteristic = nil
            if peripheral.identifier == savedDeviceID { connect(peripheral) }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            log("Disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")")
            writeCharacteristic = nil
            // Re-queue a pending connection so we reconnect automatically next time it's in range.
            if peripheral.identifier == savedDeviceID { connect(peripheral) }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension LEDController: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            for s in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: s) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            let all = (peripheral.services ?? []).flatMap { $0.characteristics ?? [] }
            let writable = all.filter { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }
            let best = writable.first { Self.preferredCharacteristics.contains($0.uuid) }
                ?? writable.first { Self.preferredServices.contains($0.service?.uuid ?? CBUUID()) }
            guard let best else {
                log("No writable characteristic yet in \(service.uuid)")
                return
            }
            if writeCharacteristic?.uuid != best.uuid {
                log("Ready: writing to \(best.uuid) in service \(best.service?.uuid.uuidString ?? "?")")
            }
            writeCharacteristic = best
            status = .connected
            if deviceName == nil { deviceName = peripheral.name }
        }
    }
}
