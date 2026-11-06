import AppIntents

struct TurnOnLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Car Lights"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Turns on the LED strips in your car.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await LEDController.shared.runForSiri(success: "Car lights on.") { $0.setPower(true) }
        return .result(dialog: "\(message)")
    }
}

struct TurnOffLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Car Lights"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Turns off the LED strips in your car.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await LEDController.shared.runForSiri(success: "Car lights off.") { $0.setPower(false) }
        return .result(dialog: "\(message)")
    }
}

struct TurnOnLightsIfDarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Car Lights If Dark"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription(
        "Plays a quick welcome flash, then leaves the lights on if the sun has set, or turns them off in daylight. Made for a CarPlay automation.")

    @Parameter(title: "Welcome Flash", default: true)
    var welcomeFlash: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn on car lights if dark") { \.$welcomeFlash }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dark = Daylight.isDark()
        LEDController.shared.log("Automation: \(dark ? "dark out" : "still light out")")
        if !dark && !welcomeFlash {
            return .result(dialog: "It's still light, so the car lights stay off.")
        }
        let success = dark ? "Car lights on." : "Welcome. It's light out, so the lights are off."
        let message = await LEDController.shared.runForSiri(success: success) { led in
            if welcomeFlash { await led.playWelcomeFlash() }
            if dark { led.restoreSavedLook() } else { led.setPower(false) }
        }
        return .result(dialog: "\(message)")
    }
}

struct StartMusicModeIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Car Light Music Mode"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("The lights fade through colours and pulse along with the music in the car.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let led = LEDController.shared
        led.log("Siri: music mode")
        do {
            try await led.perform { if !$0.isOn { $0.setPower(true) } }
            try await MusicMode.shared.start()
            return .result(dialog: "Music mode on.")
        } catch {
            led.log("Music mode failed: \(error.localizedDescription)")
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct StopMusicModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Car Light Music Mode"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Stops music mode and goes back to your normal colour.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard MusicMode.shared.isRunning else { return .result(dialog: "Music mode isn't on.") }
        MusicMode.shared.stop()
        return .result(dialog: "Music mode off.")
    }
}

struct SetLightColourIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Car Light Colour"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Changes the colour of your car's LED strips.")

    @Parameter(title: "Colour")
    var colour: LightColour

    static var parameterSummary: some ParameterSummary {
        Summary("Set car lights to \(\.$colour)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await LEDController.shared.runForSiri(success: "Car lights set to \(colour.title.lowercased()).") {
            $0.setColour(colour.rgb, throttle: false)
        }
        return .result(dialog: "\(message)")
    }
}

struct SetLightEffectIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Car Light Effect"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Starts a fade, jump or strobe effect on your car's LED strips.")

    @Parameter(title: "Effect")
    var effect: LightEffect

    @Parameter(title: "Speed", description: "0 to 100. Leave empty to keep the current speed.", inclusiveRange: (0, 100))
    var speed: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$effect) on car lights") { \.$speed }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await LEDController.shared.runForSiri(success: "\(effect.name) started.") { led in
            if let speed { led.setSpeed(Double(speed)) }
            led.setEffect(effect)
        }
        return .result(dialog: "\(message)")
    }
}

struct SetLightBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Car Light Brightness"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false
    static let description = IntentDescription("Sets the brightness of your car's LED strips.")

    @Parameter(title: "Brightness", description: "1 to 100 percent", inclusiveRange: (1, 100),
               requestValueDialog: "What brightness, from 1 to 100?")
    var brightness: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set car light brightness to \(\.$brightness)%")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await LEDController.shared.runForSiri(success: "Brightness \(brightness) percent.") { led in
            if !led.isOn { led.setPower(true) }
            led.setBrightness(Double(brightness))
        }
        return .result(dialog: "\(message)")
    }
}

struct CarGlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnLightsIntent(),
            phrases: [
                // Start with a verb: "Car Light ..." on its own gets heard as "Call Light ..." and Siri tries to phone someone.
                "Turn on \(.applicationName)",
                "Turn \(.applicationName) on",
                "Switch on \(.applicationName)",
                "Switch \(.applicationName) on",
                "Put \(.applicationName) on",
                "Lights on with \(.applicationName)",
                "\(.applicationName) on",
            ],
            shortTitle: "Lights On",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnOnLightsIfDarkIntent(),
            phrases: [
                "Turn on \(.applicationName) if it's dark",
                "Turn on \(.applicationName) if dark",
            ],
            shortTitle: "Lights On If Dark",
            systemImageName: "moon.stars.fill"
        )
        AppShortcut(
            intent: StartMusicModeIntent(),
            phrases: [
                "Turn on \(.applicationName) music",
                "Turn on \(.applicationName) music mode",
                "Start \(.applicationName) music",
                "Start music mode on \(.applicationName)",
                "Put \(.applicationName) on music",
                "Set \(.applicationName) to music",
            ],
            shortTitle: "Music Mode",
            systemImageName: "music.note"
        )
        AppShortcut(
            intent: StopMusicModeIntent(),
            phrases: [
                "Turn off \(.applicationName) music",
                "Turn off \(.applicationName) music mode",
                "Stop \(.applicationName) music",
                "Stop music mode on \(.applicationName)",
            ],
            shortTitle: "Stop Music Mode",
            systemImageName: "music.note.slash"
        )
        AppShortcut(
            intent: TurnOffLightsIntent(),
            phrases: [
                "Turn off \(.applicationName)",
                "Turn \(.applicationName) off",
                "Switch off \(.applicationName)",
                "Switch \(.applicationName) off",
                "Lights off with \(.applicationName)",
                "\(.applicationName) off",
            ],
            shortTitle: "Lights Off",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: SetLightColourIntent(),
            phrases: [
                "Set \(.applicationName) to \(\.$colour)",
                "Make \(.applicationName) \(\.$colour)",
                "\(.applicationName) \(\.$colour)",
                "Change \(.applicationName) to \(\.$colour)",
                "Change \(.applicationName) colour",
            ],
            shortTitle: "Set Colour",
            systemImageName: "paintpalette.fill"
        )
        AppShortcut(
            intent: SetLightEffectIntent(),
            phrases: [
                "Start \(\.$effect) on \(.applicationName)",
                "Set \(.applicationName) to \(\.$effect)",
                "\(.applicationName) \(\.$effect)",
                "\(.applicationName) effect",
            ],
            shortTitle: "Start Effect",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SetLightBrightnessIntent(),
            phrases: [
                "Change \(.applicationName) brightness",
                "Set \(.applicationName) brightness",
            ],
            shortTitle: "Brightness",
            systemImageName: "sun.max.fill"
        )
    }
}
