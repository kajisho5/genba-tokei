import ActivityKit
import SwiftUI
import WidgetKit

/// 試作の核心：時刻を OS 自身に数えさせる。
/// 「今日 0 時（補正済み）から始めたストップウォッチ」＝現在時刻なので、
/// アプリから毎回書き換えなくても OS が 1/100 秒まで進めてくれる（はず）。
struct LiveClockText: View {
    let state: GenbaActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Text(
            TimeDataSource<Date>.currentDate,
            format: SystemFormatStyle.Stopwatch(
                startingAt: state.stopwatchStart,
                showsHours: true,
                maxFieldCount: 4,
                maxPrecision: state.precision.maxPrecision
            )
        )
        .font(.system(size: size, weight: .semibold).monospacedDigit())
        .foregroundStyle(Palette.text)
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
                        Text(accuracyText(context.state.accuracyMs))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.okText)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.precision.label)
                        .font(.caption)
                        .foregroundStyle(Palette.subText)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveClockText(state: context.state, size: 40)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                SyncDot(accuracyMs: context.state.accuracyMs)
            } compactTrailing: {
                LiveClockText(state: context.state, size: 14)
                    .frame(maxWidth: 110)
            } minimal: {
                Image(systemName: "clock")
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    private func accuracyText(_ ms: Int?) -> String {
        guard let ms else { return "未補正" }
        return "±\(ms)ms"
    }
}

struct LockScreenView: View {
    let state: GenbaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SyncDot(accuracyMs: state.accuracyMs)
                Text("現場時計（試作）・\(state.precision.label)")
                    .font(.caption)
                    .foregroundStyle(Palette.subText)
            }
            LiveClockText(state: state, size: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
