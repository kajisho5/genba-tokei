import SwiftUI

/// S1：時計（iPhone 縦・iPad は横並び）
struct ClockTab: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerStore.self) private var timers
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var showsClockOnly: Bool
    @Binding var showsSettings: Bool
    @Binding var tab: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                SyncBadge()
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 24) {
                        bigClock.frame(maxWidth: .infinity)
                        VStack(spacing: 16) { nextCue; actions }.frame(width: 360)
                    }
                } else {
                    bigClock
                    nextCue
                    actions
                }
                Text(settings.keepsScreenOn ? "画面スリープ防止：オン" : "画面スリープ防止：オフ")
                    .font(.caption).foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("現場時計").font(.headline).foregroundStyle(Palette.text)
            Spacer()
            SquareIconButton(systemName: "pip", label: "小窓で表示", active: model.pip.isActive) { model.pip.toggle() }
            SquareIconButton(systemName: "capsule", label: "Dynamic Island に表示",
                             active: model.island.isRunning && model.island.mode == .clock) {
                Task { await model.toggleIsland(.clock) }
            }
            SquareIconButton(systemName: "rectangle.expand.vertical", label: "時計だけ表示") { showsClockOnly = true }
            SquareIconButton(systemName: "gearshape", label: "設定") { showsSettings = true }
        }
        .padding(.top, 8)
    }

    private var bigClock: some View {
        TimelineView(.animation) { context in
            let now = sync.now(context.date)
            let p = ClockMath.parts(of: now)
            VStack(spacing: 10) {
                Text(now, format: .dateTime.year().month().day().weekday(.abbreviated))
                    .font(.headline).foregroundStyle(Palette.subText)
                ClockDigitsView(parts: p, size: sizeClass == .regular ? 120 : 62, showsFraction: settings.showsFraction)
                // 1 分の進み具合
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.border)
                        Capsule().fill(Palette.text.opacity(0.85))
                            .frame(width: g.size.width * (Double(p.second) + Double(p.centisecond) / 100) / 60)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 28)
        }
    }

    private var nextCue: some View {
        Button { tab = 1 } label: {
            Card {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let now = sync.now(context.date)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("次のキュー").font(.footnote).foregroundStyle(Palette.subText)
                        if let target = timers.countdown.target {
                            HStack {
                                Text(timers.countdown.label).font(.headline).foregroundStyle(Palette.text)
                                Spacer()
                                Text(target, format: .dateTime.hour().minute().second())
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.subText)
                            }
                            let r = DurationText.countdownParts(timers.countdown.remaining(at: now) ?? 0)
                            DurationDigits(main: "−" + r.main, fraction: r.fraction, size: 30,
                                           color: timers.countdown.level(at: now).color, showsFraction: settings.showsFraction)
                        } else {
                            Text("未設定（タップしてカウントダウンを設定）").font(.subheadline).foregroundStyle(Palette.subText)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { model.pip.toggle() } label: {
                    HStack(spacing: 10) {
                        // 小窓の元になる映像（小さなプレビューとして表示）
                        PiPSourceView(controller: model.pip)
                            .frame(width: 72, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.background.opacity(0.4)))
                            .accessibilityHidden(true)
                        Text(model.pip.isActive ? "小窓を閉じる" : "小窓で表示")
                            .font(.headline).foregroundStyle(Palette.background)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button { Task { await model.toggleIsland(.clock) } } label: {
                    VStack(spacing: 2) {
                        Text("Dynamic Island").font(.subheadline.bold()).foregroundStyle(Palette.text)
                        Text(model.island.isRunning ? "表示中（\(modeName)）" : "表示する")
                            .font(.caption).foregroundStyle(model.island.isRunning ? Palette.ok : Palette.subText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border))
                }
                .buttonStyle(.plain)
            }
            if let m = model.pip.message ?? model.island.message {
                Text(m).font(.footnote).foregroundStyle(Palette.danger)
            }
        }
    }

    private var modeName: String {
        switch model.island.mode {
        case .clock: "時計"
        case .countdown: "カウントダウン"
        case .stopwatch: "ストップウォッチ"
        }
    }
}
