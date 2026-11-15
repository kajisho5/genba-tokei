import SwiftUI

/// タブ（時計・カウントダウン・ストップウォッチ）と、起動時の「時計だけモード」
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerStore.self) private var timers
    @State private var tab = 0
    @State private var showsClockOnly = false
    @State private var showsSettings = false
    @State private var didDecideStart = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("時計", systemImage: "clock", value: 0) {
                ClockTab(showsClockOnly: $showsClockOnly, showsSettings: $showsSettings, tab: $tab)
            }
            Tab("カウントダウン", systemImage: "hourglass", value: 1) {
                CountdownTab()
            }
            Tab("ストップウォッチ", systemImage: "stopwatch", value: 2) {
                StopwatchTab()
            }
        }
        .tint(Palette.accent)
        .overlay {
            // 0 秒になった瞬間に画面を光らせる
            if timers.isFlashing {
                Palette.danger.opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: timers.isFlashing)
        .fullScreenCover(isPresented: $showsClockOnly) {
            ClockOnlyView(showsSettings: $showsSettings)
                .environment(model)
                .environment(model.sync)
                .environment(model.settings)
                .environment(model.timers)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .environment(model)
                .environment(model.sync)
                .environment(model.settings)
        }
        .task {
            // App プレビュー（説明動画）の録画用（起動引数 -tour）：画面を順に自動で切り替える
            guard ProcessInfo.processInfo.arguments.contains("-tour") else { return }
            // 最初の 15 秒は時計だけモードで待つ（CI のシミュレーターは起動直後の画面の更新が遅いため）。
            // 録画の仕上げ（scripts/store-compose.py）はこの 15 秒を切り落とす
            showsClockOnly = true
            try? await Task.sleep(for: .seconds(15))
            let steps: [(clockOnly: Bool, tab: Int, seconds: Double)] = [
                (true, 0, 7), (false, 0, 6), (false, 1, 6), (false, 2, 6), (true, 0, 4),
            ]
            for step in steps {
                showsClockOnly = step.clockOnly
                tab = step.tab
                try? await Task.sleep(for: .seconds(step.seconds))
            }
        }
        .onAppear {
            model.applyScreenOn()
            if !didDecideStart {
                didDecideStart = true
                // 自動の画面写真用：-tab 0/1/2 で指定のタブを開く（時計だけモードは出さない）
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-demo") { timers.applyDemo() }
                if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = Int(args[i + 1]) {
                    tab = t
                } else {
                    showsClockOnly = settings.startsInClockOnly
                }
            }
        }
    }
}
