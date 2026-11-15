import Foundation

/// iPhone → Apple Watch に送る内容（WatchConnectivity の applicationContext）。
/// Watch は普通のアプリに UDP 通信（NTP）を許さないため、iPhone で測ったずれを送る（Apple TN3135）。
struct WatchMessage: Equatable, Sendable {
    var offset: TimeInterval
    var accuracyMs: Int?
    var syncedAt: Date?
    var countdownLabel: String
    var countdownTarget: Date?   // 補正済みの時刻

    var dictionary: [String: Any] {
        var d: [String: Any] = ["offset": offset, "countdownLabel": countdownLabel]
        if let accuracyMs { d["accuracyMs"] = accuracyMs }
        if let syncedAt { d["syncedAt"] = syncedAt.timeIntervalSince1970 }
        if let countdownTarget { d["countdownTarget"] = countdownTarget.timeIntervalSince1970 }
        return d
    }

    init(offset: TimeInterval, accuracyMs: Int?, syncedAt: Date?, countdownLabel: String, countdownTarget: Date?) {
        self.offset = offset
        self.accuracyMs = accuracyMs
        self.syncedAt = syncedAt
        self.countdownLabel = countdownLabel
        self.countdownTarget = countdownTarget
    }

    init?(dictionary d: [String: Any]) {
        guard let offset = d["offset"] as? Double else { return nil }
        self.offset = offset
        accuracyMs = d["accuracyMs"] as? Int
        syncedAt = (d["syncedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        countdownLabel = d["countdownLabel"] as? String ?? "本番"
        countdownTarget = (d["countdownTarget"] as? Double).map { Date(timeIntervalSince1970: $0) }
    }
}
