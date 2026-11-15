import Foundation

/// 本番までのカウントダウン。target は「補正済みの時刻」で持つ。
struct CountdownState: Codable, Equatable, Sendable {
    var label: String = "本番"
    var target: Date?
    /// 設定した時刻（輪の進み具合の計算用）
    var setAt: Date?

    enum Level: Equatable, Sendable { case idle, normal, warning, danger, done }

    func remaining(at now: Date) -> TimeInterval? {
        guard let target else { return nil }
        return max(0, target.timeIntervalSince(now))
    }

    func level(at now: Date) -> Level {
        guard let r = remaining(at: now) else { return .idle }
        if r <= 0 { return .done }
        if r <= 60 { return .danger }
        if r <= 300 { return .warning }
        return .normal
    }

    /// 残りの割合（1 → 0）。輪の表示に使う
    func progress(at now: Date) -> Double {
        guard let target, let setAt, target > setAt else { return 0 }
        let total = target.timeIntervalSince(setAt)
        return min(1, max(0, target.timeIntervalSince(now) / total))
    }

    /// 「今から n 秒後」。すでに動いていれば残りに足す
    mutating func add(seconds: TimeInterval, now: Date) {
        if let target, target > now {
            self.target = target.addingTimeInterval(seconds)
        } else {
            target = now.addingTimeInterval(seconds)
            setAt = now
        }
    }

    mutating func set(target: Date, now: Date) {
        self.target = target
        setAt = now
    }

    mutating func reset() {
        target = nil
        setAt = nil
    }
}

/// ストップウォッチ。端末の時計（system）で持つ（補正値が変わっても跳ばないように）。
struct StopwatchState: Codable, Equatable, Sendable {
    var startedAt: Date?
    var accumulated: TimeInterval = 0
    /// 各ラップの所要時間（古い順）
    var laps: [TimeInterval] = []

    var isRunning: Bool { startedAt != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func stop(at now: Date) {
        guard let s = startedAt else { return }
        accumulated += max(0, now.timeIntervalSince(s))
        startedAt = nil
    }

    mutating func lap(at now: Date) {
        let total = elapsed(at: now)
        laps.append(max(0, total - laps.reduce(0, +)))
    }

    mutating func reset() {
        startedAt = nil
        accumulated = 0
        laps = []
    }

    /// 動作中なら「この時刻から数え始めた」とみなせる時刻（Dynamic Island のストップウォッチ表示用）
    var virtualStart: Date? { startedAt.map { $0.addingTimeInterval(-accumulated) } }

    /// 最速・最遅のラップ番号（0 始まり）。2 周以上ある時だけ
    var fastestAndSlowest: (fastest: Int, slowest: Int)? {
        guard laps.count >= 2,
              let f = laps.indices.min(by: { laps[$0] < laps[$1] }),
              let s = laps.indices.max(by: { laps[$0] < laps[$1] }) else { return nil }
        return (f, s)
    }
}

/// 経過・残り時間の表示。1 時間未満は "MM:SS"、以上は "H:MM:SS"
enum DurationText {
    static func parts(_ seconds: TimeInterval) -> (main: String, fraction: String) {
        let t = max(0, seconds)
        let totalCs = Int((t * 100 + 0.000_001).rounded(.down))
        let cs = totalCs % 100
        let s = (totalCs / 100) % 60
        let m = (totalCs / 6000) % 60
        let h = totalCs / 360_000
        let main = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
        return (main, String(format: ".%02d", cs))
    }

    /// 残り時間は端数を切り上げて「0 になった瞬間＝本番」に合わせる
    static func countdownParts(_ remaining: TimeInterval) -> (main: String, fraction: String) {
        let up = (max(0, remaining) * 100).rounded(.up) / 100
        return parts(up)
    }
}
