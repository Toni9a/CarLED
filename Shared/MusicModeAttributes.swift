import ActivityKit
import Foundation

/// Shared by the app (starts the Live Activity) and the widget extension (draws it).
struct MusicModeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }
}
