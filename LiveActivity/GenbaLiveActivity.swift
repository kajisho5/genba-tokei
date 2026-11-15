import ActivityKit
import SwiftUI
import WidgetKit

/// 時刻を OS 自身に数えさせる（アプリから毎回書き換えない）。
/// - 時計：「補正済みの今日 0 時」から始めたストップウォッチ＝現在時刻
/// - カウントダウン：OS 標準のタイマー表示
/// - ストップウォッチ：数え始めた時刻からのストップウォッチ表示
struct LiveTimeText: View {
    let state: GenbaActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        content
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .clock:
            stopwatch(from: state.stopwatchStart)
        case .stopwatch:
            if let paused = state.pausedElapsed {
                let p = DurationText.parts(paused)
                Text(p.main + (state.precision == .seconds ? "" : p.fraction))
            } else {
                stopwatch(from: state.stopwatchStart)
            }
        case .countdown:
            if let start = state.countdownStart, let end = state.countdownEnd, start < end {
                Text(
                    TimeDataSource<Date>.currentDate,
                    format: SystemFormatStyle.Timer(
                        countingDownIn: start..<end,
                        showsHours: true,
                        maxFieldCount: 4,
                        maxPrecision: state.precision.maxPrecision
                    )
                )
            } else {
                Text("0:00")
            }
        }
    }

    private func stopwatch(from start: Date) -> Text {
        Text(
            TimeDataSource<Date>.currentDate,
            format: SystemFormatStyle.Stopwatch(
                startingAt: start,
                showsHours: true,
                maxFieldCount: 4,
                maxPrecision: state.precision.maxPrecision
            )
        )
    }

    private var color: Color {
        state.mode == .countdown ? Palette.warning : Palette.text
    }
}

struct SyncDot: View {
    let accuracyMs: Int?
    var body: some View {
        Circle()
            .fill(accuracyMs == nil ? Palette.danger : Palette.ok)
            .frame(width: 8, height: 8)
    }
}

/// 左端の記号：時計は補正状態の点、カウントダウンは砂時計、ストップウォッチはストップウォッチ
struct ModeMark: View {
    let state: GenbaActivityAttributes.ContentState
    var body: some View {
        if state.mode == .clock {
            SyncDot(accuracyMs: state.accuracyMs)
        } else {
            Image(systemName: state.mode == .countdown ? "hourglass" : "stopwatch")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
    }
}

private func modeTitle(_ state: GenbaActivityAttributes.ContentState) -> String {
    switch state.mode {
    case .clock: "現在時刻"
    case .countdown: "\(state.label ?? "本番")まで"
    case .stopwatch: "ストップウォッチ"
    }
}

struct GenbaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenbaActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Palette.background.opacity(0.92))
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        SyncDot(accuracyMs: context.state.accuracyMs)
                        Text(context.state.accuracyMs.map { "±\($0)ms" } ?? "未補正")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.okText)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(modeTitle(context.state))
                        .font(.caption)
                        .foregroundStyle(Palette.subText)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveTimeText(state: context.state, size: 40)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                if context.state.leadingOnly ?? true {
                    // 左側だけ：記号＋時刻（右側は空にすると OS が自動で隠す）
                    HStack(spacing: 4) {
                        ModeMark(state: context.state)
                        LiveTimeText(state: context.state, size: 14)
                    }
                    .frame(maxWidth: 130, alignment: .leading)
                } else {
                    ModeMark(state: context.state)
                }
            } compactTrailing: {
                if context.state.leadingOnly ?? true {
                    EmptyView()
                } else {
                    LiveTimeText(state: context.state, size: 14)
                        .frame(maxWidth: 110)
                }
            } minimal: {
                Image(systemName: context.state.mode == .countdown ? "hourglass" : "clock")
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

struct LockScreenView: View {
    let state: GenbaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SyncDot(accuracyMs: state.accuracyMs)
                Text("現場時計・\(modeTitle(state))")
                    .font(.caption)
                    .foregroundStyle(Palette.subText)
            }
            LiveTimeText(state: state, size: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
