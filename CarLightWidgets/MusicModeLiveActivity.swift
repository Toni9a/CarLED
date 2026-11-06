import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CarLightWidgets: WidgetBundle {
    var body: some Widget { MusicModeLiveActivity() }
}

struct MusicModeLiveActivity: Widget {
    private let accent = Color(red: 1, green: 0.55, blue: 0.2)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicModeAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.title2.bold())
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Car Light music mode").font(.headline)
                    Text("Say \u{201C}turn off Car Light music\u{201D} to stop").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.startedAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "music.note").foregroundStyle(accent) }
                DynamicIslandExpandedRegion(.center) { Text("Car Light music mode") }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.startedAt, style: .timer).monospacedDigit() }
            } compactLeading: {
                Image(systemName: "music.note").foregroundStyle(accent)
            } compactTrailing: {
                Image(systemName: "lightbulb.led.wide.fill").foregroundStyle(accent)
            } minimal: {
                Image(systemName: "music.note").foregroundStyle(accent)
            }
        }
    }
}
