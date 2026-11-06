import AVFoundation
import ActivityKit
import Observation

/// Listens to the car's music through the iPhone microphone and drives the strip:
/// colours drift slowly, loud moments get brighter, and each beat nudges the colour on.
@MainActor
@Observable
final class MusicMode {
    static let shared = MusicMode()

    private(set) var isRunning = false
    /// 0...1, smoothed loudness, for the on-screen meter.
    private(set) var level: Double = 0

    enum MusicError: LocalizedError {
        case micDenied, micNotAsked, couldNotStart(String)
        var errorDescription: String? {
            switch self {
            case .micDenied: "Car Light isn't allowed to use the microphone. Turn it on in Settings › Car Light."
            case .micNotAsked: "Open Car Light and turn on music mode once, so it can ask to use the microphone."
            case .couldNotStart(let why): "Music mode couldn't start: \(why)"
            }
        }
    }

    private var engine = AVAudioEngine()
    private var liveActivity: Activity<MusicModeAttributes>?
    private var observers: [NSObjectProtocol] = []

    // Analysis state
    private var hue = Double.random(in: 0..<1)
    private var smoothed = 0.0
    private var floorLevel = 0.0
    private var peak = 0.02
    private var averageEnergy = 0.0
    private var lastBeat = Date.distantPast

    private init() {}

    // MARK: Start / stop

    /// `fromApp` lets the first run ask for microphone permission (Siri can't show that prompt).
    func start(fromApp: Bool = false) async throws {
        guard !isRunning else { return }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: break
        case .denied: throw MusicError.micDenied
        default:
            guard fromApp else { throw MusicError.micNotAsked }
            guard await AVAudioApplication.requestRecordPermission() else { throw MusicError.micDenied }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Mix with the music instead of interrupting it, and keep car audio in high quality.
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.mixWithOthers, .allowBluetoothA2DP])
            try session.setActive(true)
            // Use the phone's own mic, not the car's hands-free mic (which would switch the car to call audio).
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? session.setPreferredInput(builtIn)
            }
            try startEngine()
        } catch {
            throw MusicError.couldNotStart(error.localizedDescription)
        }

        isRunning = true
        smoothed = 0; averageEnergy = 0; peak = 0.02; floorLevel = 0
        LEDController.shared.suppressSendLog = true
        LEDController.shared.log("Music mode on")
        observeInterruptions()
        startLiveActivity()
    }

    /// `restore` puts the saved colour/effect back. Pass false when something else is taking over the lights.
    func stop(restore: Bool = true) {
        guard isRunning else { return }
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        level = 0
        LEDController.shared.suppressSendLog = false
        LEDController.shared.log("Music mode off")
        endLiveActivity()
        if restore { LEDController.shared.restoreSavedLook() }
    }

    private func startEngine() throws {
        engine.stop()
        engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw MusicError.couldNotStart("no microphone available") }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.makeTap())
        engine.prepare()
        try engine.start()
    }

    /// Built outside the main actor because the tap runs on the audio thread.
    nonisolated private static func makeTap() -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var sum: Float = 0
            for i in 0..<n { sum += samples[i] * samples[i] }
            let rms = Double(sqrt(sum / Float(n)))
            Task { @MainActor in MusicMode.shared.process(rms) }
        }
    }

    // MARK: Turning sound into light (~47 times a second)

    private func process(_ energy: Double) {
        guard isRunning else { return }

        // Adapt to how loud the car is: the quietest recent level becomes dim, the loudest becomes full.
        if energy < floorLevel { floorLevel = energy } else { floorLevel += (energy - floorLevel) * 0.0015 }
        peak = max(energy, peak * 0.997, floorLevel + 0.004)
        let loudness = min(1, max(0, (energy - floorLevel) / (peak - floorLevel)))

        // Rise fast, fall slowly, so it fades rather than flickers.
        smoothed += (loudness - smoothed) * (loudness > smoothed ? 0.45 : 0.06)

        // Beat: a sudden jump above the recent average moves the colour on.
        averageEnergy += (energy - averageEnergy) * 0.05
        let now = Date()
        if energy > averageEnergy * 1.6, loudness > 0.5, now.timeIntervalSince(lastBeat) > 0.28 {
            lastBeat = now
            hue += 0.09
        }
        hue += 0.0012 // slow drift: a full trip round the colours roughly every 18 seconds
        hue = hue.truncatingRemainder(dividingBy: 1)

        level = smoothed
        let led = LEDController.shared
        guard led.isConnected else { return }
        let base = RGB(hue: hue, saturation: 1)
        let v = 0.1 + 0.9 * smoothed
        func scale(_ c: UInt8) -> UInt8 { UInt8(clamping: Int((Double(c) * v).rounded())) }
        led.showColour(RGB(r: scale(base.r), g: scale(base.g), b: scale(base.b)))
    }

    // MARK: Phone calls, Siri and route changes

    private func observeInterruptions() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init) == .ended
            guard ended else { return }
            MainActor.assumeIsolated { MusicMode.shared.resumeAfterInterruption() }
        })
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MusicMode.shared.resumeAfterInterruption() }
        })
    }

    private func resumeAfterInterruption() {
        guard isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try startEngine()
            LEDController.shared.log("Music mode resumed")
        } catch {
            LEDController.shared.log("Music mode couldn't resume: \(error.localizedDescription)")
        }
    }

    // MARK: Lock screen Live Activity (iOS needs one while recording from Siri)

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, liveActivity == nil else { return }
        let state = MusicModeAttributes.ContentState(startedAt: .now)
        liveActivity = try? Activity.request(attributes: MusicModeAttributes(),
                                             content: .init(state: state, staleDate: nil))
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
