import Foundation
import WatchConnectivity

/// iPhone 側：補正値とカウントダウンを Apple Watch に送る
final class WatchLink: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchLink()
    private var pending: [String: Any]?
    private let lock = NSLock()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        let dict = message.dictionary
        let session = WCSession.default
        if session.activationState == .activated, session.isPaired, session.isWatchAppInstalled {
            try? session.updateApplicationContext(dict)
        } else {
            lock.withLock { pending = dict }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let dict = lock.withLock { () -> [String: Any]? in defer { pending = nil }; return pending }
        if state == .activated, let dict, session.isPaired, session.isWatchAppInstalled {
            try? session.updateApplicationContext(dict)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
