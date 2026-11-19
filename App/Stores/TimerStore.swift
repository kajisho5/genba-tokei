import Foundation
import Observation
import UIKit
import UserNotifications

/// カウントダウンとストップウォッチ（UserDefaults に保存。アプリを閉じても狂わない）
@MainActor
@Observable
final class TimerStore {
    private(set) var countdown: CountdownState
    private(set) var stopwatch: StopwatchState
    /// 0 秒になった直後の数秒間 true（画面を光らせる）
    private(set) var isFlashing = false

    private let defaults = UserDefaults.standard
    private var zeroTask: Task<Void, Never>?
    /// 補正済みの今（TimeSyncStore から渡される）
    var correctedNow: () -> Date = { Date() }
    var offset: () -> TimeInterval = { 0 }
    var playsSound: () -> Bool = { true }
    /// 変わった時に呼ばれる（Dynamic Island と Watch への反映用）
    var onChange: (() -> Void)?

    init() {
        countdown = Self.load(CountdownState.self, "countdown") ?? CountdownState()
        stopwatch = Self.load(StopwatchState.self, "stopwatch") ?? StopwatchState()
    }

    // MARK: カウントダウン

    func addCountdown(seconds: TimeInterval) {
        countdown.add(seconds: seconds, now: correctedNow())
        countdownChanged()
    }

    func setCountdown(target: Date, label: String) {
        countdown.label = label.isEmpty ? "本番" : label
        countdown.set(target: target, now: correctedNow())
        countdownChanged()
    }

    func setCountdownLabel(_ label: String) {
        countdown.label = label.isEmpty ? "本番" : label
        countdownChanged()
    }

    func resetCountdown() {
        countdown.reset()
        countdownChanged()
    }

    /// 補正値が変わった・アプリに戻った時に 0 秒の予約を作り直す
    func rescheduleZero() {
        zeroTask?.cancel()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["countdown.zero"])
        guard let remaining = countdown.remaining(at: correctedNow()), remaining > 0 else { return }

        // アプリが開いている時：振動と画面の点滅
        zeroTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.fireZero()
        }
        // アプリが閉じている時：通知（音つき）。画面写真の見本モードでは許可を求めない（ダイアログが写るため）
        guard !TimeSyncStore.isDemo else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(countdown.label)の時間です"
        content.body = "カウントダウンが 0 になりました"
        if playsSound() { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
        let request = UNNotificationRequest(identifier: "countdown.zero", content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.add(request, withCompletionHandler: nil)
    }

    private func fireZero() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        isFlashing = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.isFlashing = false
        }
    }

    private func countdownChanged() {
        save(countdown, "countdown")
        rescheduleZero()
        onChange?()
    }

    // MARK: ストップウォッチ

    func startStopwatch() { stopwatch.start(at: Date()); stopwatchChanged() }
    func stopStopwatch() { stopwatch.stop(at: Date()); stopwatchChanged() }
    func lap() { stopwatch.lap(at: Date()); stopwatchChanged() }
    func resetStopwatch() { stopwatch.reset(); stopwatchChanged() }

    private func stopwatchChanged() {
        save(stopwatch, "stopwatch")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onChange?()
    }

    /// App Store の画面写真用（起動引数 -demo）：本番まで 25 分、ストップウォッチにラップ 3 つ
    func applyDemo() {
        let now = correctedNow()
        countdown = CountdownState(label: "本番", target: now.addingTimeInterval(25 * 60 + 3.22), setAt: now.addingTimeInterval(-20 * 60))
        let sysNow = Date()
        stopwatch = StopwatchState(startedAt: sysNow.addingTimeInterval(-207.41), accumulated: 0, laps: [104.14, 62.09])
        onChange?()
    }

    // MARK: 保存

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
