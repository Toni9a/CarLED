import SwiftUI

@main
struct CarGlowApp: App {
    @State private var controller = LEDController.shared

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(controller)
                .preferredColorScheme(.dark)
        }
    }
}
