import Combine
import SwiftUI

@main
struct GenbaTokeiApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.sync)
                .environment(model.settings)
                .environment(model.timers)
                .preferredColorScheme(.dark)
                .task { await model.syncNow() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.applyScreenOn()
                        Task { await model.syncNow() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                    Task { await model.clockWasChangedByUser() }
                }
        }
    }
}
