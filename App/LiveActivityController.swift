import ActivityKit
import Foundation
import Observation

/// Dynamic Island / ロック画面表示の開始・更新・終了
@MainActor
@Observable
final class LiveActivityController {
    private(set) var isRunning = false
    private(set) var message: String?

    init() {
        isRunning = !Activity<GenbaActivityAttributes>.activities.isEmpty
    }

    var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(offset: TimeInterval, accuracyMs: Int?, precision: DisplayPrecision) async {
        guard isAllowed else {
            message = "設定アプリ →「現場時計」→「ライブアクティビティ」をオンにしてください"
            return
        }
        await stop()
        let state = makeState(offset: offset, accuracyMs: accuracyMs, precision: precision)
        do {
            _ = try Activity.request(
                attributes: GenbaActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            isRunning = true
            message = nil
        } catch {
            message = "開始できませんでした：\(error.localizedDescription)"
        }
    }

    /// 補正値や表示の細かさが変わった時に表示中のものへ反映する
    func update(offset: TimeInterval, accuracyMs: Int?, precision: DisplayPrecision) async {
        let state = makeState(offset: offset, accuracyMs: accuracyMs, precision: precision)
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

    private func makeState(offset: TimeInterval, accuracyMs: Int?,
                           precision: DisplayPrecision) -> GenbaActivityAttributes.ContentState {
        .init(
            stopwatchStart: ClockMath.stopwatchStart(systemNow: Date(), offset: offset),
            precision: precision,
            accuracyMs: accuracyMs
        )
    }
}
