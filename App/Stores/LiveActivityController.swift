import ActivityKit
import Foundation
import Observation

/// Dynamic Island / ロック画面表示の開始・更新・終了
@MainActor
@Observable
final class LiveActivityController {
    typealias Mode = GenbaActivityAttributes.ContentState.Mode

    private(set) var isRunning = false
    private(set) var mode: Mode = .clock
    private(set) var message: String?

    init() {
        if let current = Activity<GenbaActivityAttributes>.activities.first {
            isRunning = true
            mode = current.content.state.mode
        }
    }

    var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    struct Inputs {
        var offset: TimeInterval
        var accuracyMs: Int?
        var precision: DisplayPrecision
        var leadingOnly: Bool
        var countdown: CountdownState
        var stopwatch: StopwatchState
    }

    func start(_ mode: Mode, _ inputs: Inputs) async {
        guard isAllowed else {
            message = "設定アプリ →「現場時計」→「ライブアクティビティ」をオンにしてください"
            return
        }
        await stop()
        self.mode = mode
        do {
            _ = try Activity.request(
                attributes: GenbaActivityAttributes(),
                content: ActivityContent(state: makeState(mode, inputs), staleDate: nil),
                pushType: nil
            )
            isRunning = true
            message = nil
        } catch {
            message = "表示できませんでした：\(error.localizedDescription)"
        }
    }

    /// 補正値・カウントダウン・ストップウォッチが変わった時に表示中のものへ反映する
    func refresh(_ inputs: Inputs) async {
        guard isRunning else { return }
        let state = makeState(mode, inputs)
        for activity in Activity<GenbaActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func stop() async {
        for activity in Activity<GenbaActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        isRunning = false
    }

    private func makeState(_ mode: Mode, _ i: Inputs) -> GenbaActivityAttributes.ContentState {
        let now = Date()
        var state = GenbaActivityAttributes.ContentState(
            mode: mode,
            stopwatchStart: ClockMath.stopwatchStart(systemNow: now, offset: i.offset),
            precision: i.precision,
            accuracyMs: i.accuracyMs,
            leadingOnly: i.leadingOnly
        )
        switch mode {
        case .clock:
            break
        case .countdown:
            // 補正済みの時刻 → 端末の時計に直して渡す
            state.countdownEnd = i.countdown.target?.addingTimeInterval(-i.offset)
            state.countdownStart = (i.countdown.setAt ?? now).addingTimeInterval(-i.offset)
            state.label = i.countdown.label
        case .stopwatch:
            if let start = i.stopwatch.virtualStart {
                state.stopwatchStart = start
            } else {
                state.pausedElapsed = i.stopwatch.elapsed(at: now)
            }
        }
        return state
    }
}
