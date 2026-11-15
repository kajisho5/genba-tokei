import SwiftUI

/// S2：本番までのカウントダウン
struct CountdownTab: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerStore.self) private var timers
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TimelineView(.animation) { context in
                    let now = sync.now(context.date)
                    VStack(spacing: 20) {
                        HStack {
                            Text("カウントダウン").font(.headline).foregroundStyle(Palette.text)
                            Spacer()
                            let p = ClockMath.parts(of: now)
                            Text("現在 \(p.main)\(settings.showsFraction ? p.fraction : "")")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.subText)
                        }
                        .padding(.top, 8)
                        targetCard
                        ring(now: now)
                    }
                }
                presets
                bottomButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $editing) {
            CountdownEditor().environment(model).environment(sync).environment(timers)
                .presentationDetents([.medium, .large])
        }
    }

    private var targetCard: some View {
        Button { editing = true } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目標").font(.footnote).foregroundStyle(Palette.subText)
                        Text(timers.countdown.label).font(.headline).foregroundStyle(Palette.text)
                    }
                    Spacer()
                    if let target = timers.countdown.target {
                        Text(target, format: .dateTime.hour().minute().second())
                            .font(.title3.monospacedDigit()).foregroundStyle(Palette.text)
                    } else {
                        Text("未設定").foregroundStyle(Palette.subText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("タップで目標の時刻と名前を変える")
    }

    private func ring(now: Date) -> some View {
        let level = timers.countdown.level(at: now)
        let remaining = timers.countdown.remaining(at: now) ?? 0
        let r = DurationText.countdownParts(remaining)
        let caption: String = switch level {
        case .idle: "目標を設定してください"
        case .normal: "残り"
        case .warning: "残り5分"
        case .danger: "残り1分"
        case .done: "時間です"
        }
        return ZStack {
            Circle().stroke(level.color.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: timers.countdown.progress(at: now))
                .stroke(level.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                Text(caption).font(.subheadline.bold()).foregroundStyle(level.color)
                DurationDigits(main: r.main, fraction: r.fraction, size: 54, color: level.color,
                               showsFraction: settings.showsFraction)
                    .padding(.horizontal, 24)
            }
        }
        .frame(width: 270, height: 270)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("すぐ設定").font(.footnote).foregroundStyle(Palette.subText)
            HStack(spacing: 10) {
                ForEach([60, 300, 600], id: \.self) { sec in
                    presetButton("+\(sec / 60)分") { timers.addCountdown(seconds: TimeInterval(sec)) }
                }
                presetButton("時刻…") { editing = true }
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.monospacedDigit()).foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
        }
        .buttonStyle(.plain)
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button { timers.resetCountdown() } label: {
                Text("リセット").font(.headline).foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border))
            }
            .buttonStyle(.plain)
            .disabled(timers.countdown.target == nil)
            Button { Task { await model.toggleIsland(.countdown) } } label: {
                let on = model.island.isRunning && model.island.mode == .countdown
                Text(on ? "Islandを止める" : "Islandに表示").font(.headline).foregroundStyle(Palette.background)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(on ? Palette.danger : Palette.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(timers.countdown.target == nil)
        }
    }
}

/// 目標の時刻と名前を決める
struct CountdownEditor: View {
    @Environment(TimeSyncStore.self) private var sync
    @Environment(TimerStore.self) private var timers
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var time = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("本番", text: $label)
                }
                Section("時刻（秒は 0 秒にそろえる）") {
                    DatePicker("時刻", selection: $time, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("カウントダウンの目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        timers.setCountdown(target: nextOccurrence(of: time), label: label)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            label = timers.countdown.label
            time = timers.countdown.target ?? sync.now().addingTimeInterval(1800)
        }
    }

    /// 選んだ時・分の、次に来る時刻（過ぎていれば翌日）
    private func nextOccurrence(of picked: Date) -> Date {
        let cal = Calendar.current
        let now = sync.now()
        let hm = cal.dateComponents([.hour, .minute], from: picked)
        var c = cal.dateComponents([.year, .month, .day], from: now)
        c.hour = hm.hour
        c.minute = hm.minute
        c.second = 0
        let today = cal.date(from: c) ?? now
        return today > now ? today : cal.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
