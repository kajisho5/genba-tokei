import SwiftUI
import UIKit

/// S2：ストップウォッチ
struct StopwatchTab: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerStore.self) private var timers

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TimelineView(.animation) { context in
                    let sw = timers.stopwatch
                    VStack(spacing: 10) {
                        HStack {
                            Text("ストップウォッチ").font(.headline).foregroundStyle(Palette.text)
                            Spacer()
                            let p = ClockMath.parts(of: sync.now(context.date))
                            Text("現在 \(p.main)\(settings.showsFraction ? p.fraction : "")")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.subText)
                        }
                        .padding(.top, 8)
                        let e = DurationText.parts(sw.elapsed(at: context.date))
                        DurationDigits(main: e.main, fraction: e.fraction, size: 64, showsFraction: settings.showsFraction)
                            .padding(.top, 48)
                        if let start = sw.startedAt {
                            Text("開始 \(ClockMath.parts(of: start.addingTimeInterval(sync.offset)).main)")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.subText)
                        } else {
                            Text(sw.accumulated > 0 ? "停止中" : " ").font(.subheadline).foregroundStyle(Palette.subText)
                        }
                    }
                }
                buttons
                laps
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var buttons: some View {
        let sw = timers.stopwatch
        return HStack {
            roundButton(sw.isRunning ? "ラップ" : "リセット", color: Palette.text, background: Palette.surface,
                        disabled: !sw.isRunning && sw.accumulated == 0) {
                sw.isRunning ? timers.lap() : timers.resetStopwatch()
            }
            Spacer()
            Button { Task { await model.toggleIsland(.stopwatch) } } label: {
                let on = model.island.isRunning && model.island.mode == .stopwatch
                Label(on ? "Island表示中" : "Islandに表示", systemImage: "capsule")
                    .font(.caption.bold()).foregroundStyle(on ? Palette.ok : Palette.subText)
            }
            .buttonStyle(.plain)
            Spacer()
            roundButton(sw.isRunning ? "停止" : "開始", color: sw.isRunning ? Palette.danger : Palette.ok,
                        background: (sw.isRunning ? Palette.danger : Palette.ok).opacity(0.18)) {
                sw.isRunning ? timers.stopStopwatch() : timers.startStopwatch()
            }
        }
        .padding(.horizontal, 12)
    }

    private func roundButton(_ title: String, color: Color, background: Color, disabled: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundStyle(color)
                .frame(width: 88, height: 88)
                .background(background, in: Circle())
                .overlay(Circle().stroke(color.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private var laps: some View {
        let sw = timers.stopwatch
        let marks = sw.fastestAndSlowest
        return VStack(spacing: 0) {
            ForEach(Array(sw.laps.enumerated()).reversed(), id: \.offset) { item in
                let index = item.offset
                let p = DurationText.parts(item.element)
                HStack {
                    Text("ラップ \(index + 1)").foregroundStyle(Palette.subText)
                    Spacer()
                    Text(p.main + p.fraction)
                        .foregroundStyle(index == marks?.fastest ? Palette.ok : index == marks?.slowest ? Palette.danger : Palette.text)
                }
                .font(.body.monospacedDigit())
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
                .contextMenu {
                    Button("コピー", systemImage: "doc.on.doc") { UIPasteboard.general.string = p.main + p.fraction }
                }
            }
            if marks != nil {
                Text("緑＝最速　赤＝最遅　長押しでコピー").font(.caption).foregroundStyle(Palette.faint)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            }
        }
    }
}
