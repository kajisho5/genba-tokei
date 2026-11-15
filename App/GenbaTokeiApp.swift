import SwiftUI

@main
struct GenbaTokeiApp: App {
    @State private var sync = TimeSyncStore()
    @State private var liveActivity = LiveActivityController()

    var body: some Scene {
        WindowGroup {
            PrototypeView()
                .environment(sync)
                .environment(liveActivity)
                .preferredColorScheme(.dark)
        }
    }
}
