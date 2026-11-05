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
                "Turn on \(.applicationName)",
                "\(.applicationName) on",
                "Turn on the car lights with \(.applicationName)",
            ],
            shortTitle: "Lights On",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnOffLightsIntent(),
            phrases: [
                "Turn off \(.applicationName)",
                "\(.applicationName) off",
                "Turn off the car lights with \(.applicationName)",
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
