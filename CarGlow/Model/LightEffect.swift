import SwiftUI
import AppIntents

enum EffectGroup: String, CaseIterable, Identifiable {
    case jumps = "Jumps", fades = "Fades", strobes = "Strobes"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .jumps: "sparkles"
        case .fades: "circle.lefthalf.filled"
        case .strobes: "bolt.fill"
        }
    }
}

/// Built-in programs on the ELK controller. Raw value is the mode byte.
enum LightEffect: UInt8, CaseIterable, Identifiable, Codable {
    case jumpRGB = 0x87, jumpSeven
    case fadeRGB, fadeSeven, fadeRed, fadeGreen, fadeBlue, fadeYellow, fadeCyan, fadePurple, fadeWhite
    case fadeRedGreen, fadeRedBlue, fadeGreenBlue
    case strobeSeven, strobeRed, strobeGreen, strobeBlue, strobeYellow, strobeCyan, strobePurple, strobeWhite

    var id: UInt8 { rawValue }

    var group: EffectGroup {
        switch self {
        case .jumpRGB, .jumpSeven: .jumps
        case .strobeSeven, .strobeRed, .strobeGreen, .strobeBlue, .strobeYellow, .strobeCyan, .strobePurple, .strobeWhite: .strobes
        default: .fades
        }
    }

    var name: String {
        switch self {
        case .jumpRGB: "RGB Jump"
        case .jumpSeven: "Rainbow Jump"
        case .fadeRGB: "RGB Fade"
        case .fadeSeven: "Rainbow Fade"
        case .fadeRed: "Red Pulse"
        case .fadeGreen: "Green Pulse"
        case .fadeBlue: "Blue Pulse"
        case .fadeYellow: "Yellow Pulse"
        case .fadeCyan: "Cyan Pulse"
        case .fadePurple: "Purple Pulse"
        case .fadeWhite: "White Pulse"
        case .fadeRedGreen: "Red & Green"
        case .fadeRedBlue: "Red & Blue"
        case .fadeGreenBlue: "Green & Blue"
        case .strobeSeven: "Rainbow Strobe"
        case .strobeRed: "Red Strobe"
        case .strobeGreen: "Green Strobe"
        case .strobeBlue: "Blue Strobe"
        case .strobeYellow: "Yellow Strobe"
        case .strobeCyan: "Cyan Strobe"
        case .strobePurple: "Purple Strobe"
        case .strobeWhite: "White Strobe"
        }
    }

    var swatches: [Color] {
        let red = Color(red: 1, green: 0.2, blue: 0.2), green = Color(red: 0.2, green: 0.9, blue: 0.35),
            blue = Color(red: 0.25, green: 0.45, blue: 1), yellow = Color(red: 1, green: 0.85, blue: 0.2),
            cyan = Color(red: 0.2, green: 0.9, blue: 1), purple = Color(red: 0.75, green: 0.35, blue: 1),
            white = Color.white
        let seven = [red, yellow, green, cyan, blue, purple, white]
        switch self {
        case .jumpRGB, .fadeRGB: return [red, green, blue]
        case .jumpSeven, .fadeSeven, .strobeSeven: return seven
        case .fadeRed, .strobeRed: return [red]
        case .fadeGreen, .strobeGreen: return [green]
        case .fadeBlue, .strobeBlue: return [blue]
        case .fadeYellow, .strobeYellow: return [yellow]
        case .fadeCyan, .strobeCyan: return [cyan]
        case .fadePurple, .strobePurple: return [purple]
        case .fadeWhite, .strobeWhite: return [white]
        case .fadeRedGreen: return [red, green]
        case .fadeRedBlue: return [red, blue]
        case .fadeGreenBlue: return [green, blue]
        }
    }
}

extension LightEffect: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Effect"
    static let caseDisplayRepresentations: [LightEffect: DisplayRepresentation] = [
        .jumpRGB: "RGB Jump",
        .jumpSeven: DisplayRepresentation(title: "Rainbow Jump", synonyms: ["Jump", "Flash"]),
        .fadeRGB: "RGB Fade",
        .fadeSeven: DisplayRepresentation(title: "Rainbow Fade", synonyms: ["Fade", "Rainbow", "Colour Fade", "Color Fade", "Seven Colour Fade"]),
        .fadeRed: "Red Pulse",
        .fadeGreen: "Green Pulse",
        .fadeBlue: "Blue Pulse",
        .fadeYellow: "Yellow Pulse",
        .fadeCyan: "Cyan Pulse",
        .fadePurple: "Purple Pulse",
        .fadeWhite: "White Pulse",
        .fadeRedGreen: "Red and Green",
        .fadeRedBlue: DisplayRepresentation(title: "Red and Blue", synonyms: ["Police"]),
        .fadeGreenBlue: "Green and Blue",
        .strobeSeven: DisplayRepresentation(title: "Rainbow Strobe", synonyms: ["Strobe", "Party"]),
        .strobeRed: "Red Strobe",
        .strobeGreen: "Green Strobe",
        .strobeBlue: "Blue Strobe",
        .strobeYellow: "Yellow Strobe",
        .strobeCyan: "Cyan Strobe",
        .strobePurple: "Purple Strobe",
        .strobeWhite: "White Strobe",
    ]
}
