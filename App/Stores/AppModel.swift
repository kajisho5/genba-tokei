import Foundation
import Observation
import UIKit

/// 各ストアをつなぐ。補正値やタイマーが変わったら Dynamic Island・小窓・Watch に反映する。
@MainActor
@Observable
final class AppModel {
    let sync = TimeSyncStore()
    let settings = SettingsStore()
    let timers = TimerStore()
    let island = LiveActivityController()
    let pip = PiPController()

    init() {
        timers.correctedNow = { [unowned self] in self.sync.now() }
        timers.offset = { [unowned self] in self.sync.offset }
        timers.playsSound = { [unowned self] in self.settings.plays0Sound }
        timers.onChange = { [weak self] in self?.pushOutputs() }
        WatchLink.shared.activate()
        // 電池残量が変わったら Dynamic Island に反映（アプリが動いている間だけ）
        UIDevice.current.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pushOutputs() }
            }
        }
        pushOutputs()
    }

    func syncNow() async {
        await sync.sync()
        timers.rescheduleZero()
        pushOutputs()
    }

    func clockWasChangedByUser() async {
        sync.invalidate()
        await syncNow()
    }

    var islandInputs: LiveActivityController.Inputs {
        .init(offset: sync.offset, accuracyMs: sync.accuracyMs, precision: settings.islandPrecision,
              layout: settings.islandLayout,
              batteryPercent: Self.batteryPercent, batteryCharging: Self.isCharging, countdown: timers.countdown, stopwatch: timers.stopwatch)
    }

    func toggleIsland(_ mode: LiveActivityController.Mode) async {
        if island.isRunning && island.mode == mode {
            await island.stop()
        } else {
            await island.start(mode, islandInputs)
        }
    }

    /// Dynamic Island・小窓・Apple Watch に今の状態を渡す
    func pushOutputs() {
        pip.renderer.update(.init(
            offset: sync.offset,
            countdownLabel: timers.countdown.label,
            countdownTarget: timers.countdown.target,
            showsFraction: settings.showsFraction,
            syncOK: sync.status() == .ok
        ))
        WatchLink.shared.send(WatchMessage(
            offset: sync.offset, accuracyMs: sync.accuracyMs, syncedAt: sync.syncedAt,
            countdownLabel: timers.countdown.label, countdownTarget: timers.countdown.target
        ))
        let inputs = islandInputs
        Task { await island.refresh(inputs) }
    }

    static var batteryPercent: Int? {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Int((level * 100).rounded())
    }

    static var isCharging: Bool {
        [.charging, .full].contains(UIDevice.current.batteryState)
    }

    func applyScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepsScreenOn
    }
}
