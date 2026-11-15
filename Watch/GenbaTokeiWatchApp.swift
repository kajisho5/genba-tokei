import SwiftUI

@main
struct GenbaTokeiWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .onAppear { WatchReceiver.shared.activate(model) }
        }
    }
}

/// デジタルクラウンで 時計／カウントダウン／ストップウォッチ を切り替える
struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchClockView()
            WatchCountdownView()
            WatchStopwatchView()
        }
        .tabViewStyle(.verticalPage)
    }
}

/// S4 ①②：腕を上げている間は 1/100 秒まで。腕を下ろすと秒まで・暗め
struct WatchClockView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        TimelineView(.animation(minimumInterval: dimmed ? 1 : nil)) { context in
            let now = model.now(context.date)
            let p = ClockMath.parts(of: now)
            let tint = dimmed ? Palette.subText : Palette.text
            VStack(spacing: 2) {
                // 右上は watchOS の時刻表示とページ表示（点々）があるので、左端に短く置く
                HStack(spacing: 4) {
                    Circle().fill(model.isCorrected ? Palette.ok : Palette.faint)
                        .frame(width: 6, height: 6).opacity(dimmed ? 0.5 : 1)
                    Text(now, format: .dateTime.month(.defaultDigits).day())
                        .font(.system(size: 12).monospacedDigit()).foregroundStyle(tint)
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 64)
                Spacer(minLength: 0)
                Text(String(format: "%02d:%02d", p.hour, p.minute))
                    .font(.system(size: 54, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(String(format: "%02d", p.second))
                        .font(.system(size: 40, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                    if !dimmed {
                        Text(p.fraction).font(.system(size: 30, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.accent)
                    }
                }
                Spacer(minLength: 0)
                if let target = model.countdown.target {
                    let r = DurationText.countdownParts(max(0, target.timeIntervalSince(now)))
                    Text("\(model.countdown.label) −\(r.main)")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(dimmed ? Palette.faint : Palette.subText)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Palette.surface, in: Capsule())
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(p.hour)時\(p.minute)分\(p.second)秒")
        }
        .padding(.horizontal, 4)
    }
}

/// S4 ③：iPhone で設定したカウントダウン（残り 5 分で黄・1 分で赤、毎秒コツコツ）
struct WatchCountdownView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        TimelineView(.animation(minimumInterval: dimmed ? 1 : nil)) { context in
            let now = model.now(context.date)
            let c = model.countdown
            let remaining = c.remaining(at: now)
            let level = c.level(at: now)
            VStack(spacing: 4) {
                Text(c.target == nil ? "カウントダウン" : "\(c.label)まで")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(level.watchColor)
                if let remaining {
                    let r = DurationText.countdownParts(remaining)
                    Text(r.main).font(.system(size: 44, weight: .semibold).monospacedDigit())
                        .foregroundStyle(level.watchColor)
                    if !dimmed {
                        Text(r.fraction).font(.system(size: 26, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.accent)
                    }
                } else {
                    Text("iPhone で設定").font(.system(size: 16)).foregroundStyle(Palette.subText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onChange(of: Int((remaining ?? 999).rounded(.up))) { _, _ in
                model.hapticTick(remaining: remaining)
            }
        }
    }
}

extension CountdownState.Level {
    var watchColor: Color {
        switch self {
        case .idle, .normal: Palette.text
        case .warning: Palette.warning
        case .danger, .done: Palette.danger
        }
    }
}

/// ストップウォッチ（Watch 単体。画面タップで開始／停止、長押しでリセット）
struct WatchStopwatchView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        @Bindable var model = model
        TimelineView(.animation(minimumInterval: dimmed || !model.stopwatch.isRunning ? 1 : nil)) { context in
            let e = DurationText.parts(model.stopwatch.elapsed(at: context.date))
            VStack(spacing: 6) {
                Text("ストップウォッチ").font(.system(size: 13)).foregroundStyle(Palette.subText)
                Text(e.main).font(.system(size: 44, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.text)
                if !dimmed {
                    Text(e.fraction).font(.system(size: 26, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.accent)
                }
                Text(model.stopwatch.isRunning ? "タップで停止" : "タップで開始・長押しでリセット")
                    .font(.system(size: 11)).foregroundStyle(Palette.faint)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.stopwatch.isRunning { model.stopwatch.stop(at: Date()) } else { model.stopwatch.start(at: Date()) }
            WKInterfaceDevice.current().play(.click)
        }
        .onLongPressGesture { model.stopwatch.reset() }
    }
}
