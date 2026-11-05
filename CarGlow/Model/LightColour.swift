import AppIntents

/// Named colours for Siri, Shortcuts and CarPlay.
enum LightColour: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, cyan, blue, purple, pink, white, warmWhite

    var id: String { rawValue }

    var rgb: RGB {
        switch self {
        case .red: RGB(r: 255, g: 0, b: 0)
        case .orange: RGB(r: 255, g: 90, b: 0)
        case .yellow: RGB(r: 255, g: 200, b: 0)
        case .green: RGB(r: 0, g: 255, b: 0)
        case .cyan: RGB(r: 0, g: 255, b: 220)
        case .blue: RGB(r: 0, g: 0, b: 255)
        case .purple: RGB(r: 150, g: 0, b: 255)
        case .pink: RGB(r: 255, g: 0, b: 140)
        case .white: RGB.white(warmth: 1)
        case .warmWhite: RGB.white(warmth: 0)
        }
    }

    var title: String {
        switch self {
        case .warmWhite: "Warm White"
        default: rawValue.capitalized
        }
    }
}

extension LightColour: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Colour"
    static let caseDisplayRepresentations: [LightColour: DisplayRepresentation] = [
        .red: "Red",
        .orange: "Orange",
        .yellow: "Yellow",
        .green: "Green",
        .cyan: DisplayRepresentation(title: "Cyan", synonyms: ["Teal", "Aqua", "Turquoise"]),
        .blue: "Blue",
        .purple: DisplayRepresentation(title: "Purple", synonyms: ["Violet"]),
        .pink: DisplayRepresentation(title: "Pink", synonyms: ["Magenta"]),
        .white: DisplayRepresentation(title: "White", synonyms: ["Cool White"]),
        .warmWhite: "Warm White",
    ]
}
