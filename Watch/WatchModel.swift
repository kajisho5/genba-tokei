import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Watch 側：iPhone から補正値とカウントダウンを受け取る。ストップウォッチは Watch だけで動く。
@MainActor
@Observable
final class WatchModel {
    private(set) var message: WatchMessage?
    private(set) var receivedAt: Date?
    var stopwatch = StopwatchState()
    @ObservationIgnored private var lastHapticSecond: Int?

    var offset: TimeInterval { message?.offset ?? 0 }
    var isCorrected: Bool { message?.syncedAt != nil }
    var countdown: CountdownState {
        CountdownState(label: message?.countdownLabel ?? "本番", target: message?.countdownTarget, setAt: nil)
    }

    func now(_ system: Date = Date()) -> Date { system.addingTimeInterval(offset) }

    func receive(_ m: WatchMessage) {
        message = m
        receivedAt = Date()
    }

    /// 残り 1 分を切ったら毎秒「コツ」、0 秒で強い振動（画面が点いている間）
    func hapticTick(remaining: TimeInterval?) {
        guard let remaining, remaining <= 60 else { lastHapticSecond = nil; return }
        let second = Int(remaining.rounded(.up))
        guard second != lastHapticSecond else { return }
        lastHapticSecond = second
        WKInterfaceDevice.current().play(second == 0 ? .notification : .click)
    }
}

final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchReceiver()
    weak var model: WatchModel?

    func activate(_ model: WatchModel) {
        self.model = model
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func deliver(_ dict: [String: Any]) {
        guard let m = WatchMessage(dictionary: dict) else { return }
        Task { @MainActor [weak self] in self?.model?.receive(m) }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let dict = session.receivedApplicationContext
        if !dict.isEmpty { deliver(dict) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }
}
