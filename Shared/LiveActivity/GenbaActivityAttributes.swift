import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Dynamic Island / ロック画面に渡すデータ（4KB 以内）。
/// 時刻はすべて「端末の時計（system）」で渡す。ウィジェット側は OS が Date.now で数えるため。
struct GenbaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        enum Mode: String, Codable, Hashable, Sendable { case clock, countdown, stopwatch }

        var mode: Mode
        /// clock：補正済みの今日 0 時（ClockMath.stopwatchStart）／ stopwatch：数え始めた時刻（動作中のみ）
        var stopwatchStart: Date
        /// countdown：設定した時刻と本番の時刻
        var countdownStart: Date?
        var countdownEnd: Date?
        var label: String?
        /// stopwatch が止まっている時の経過秒
        var pausedElapsed: Double?
        var precision: DisplayPrecision
        /// NTP の誤差（ミリ秒）。未補正なら nil
        var accuracyMs: Int?
        /// true：Dynamic Island の左側だけに出す（右の電池・電波を隠さない）
        var leadingOnly: Bool?
    }
}
#endif

/// 表示の細かさ
enum DisplayPrecision: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case centiseconds
    case deciseconds
    case seconds

    var id: String { rawValue }

    var label: String {
        switch self {
        case .centiseconds: "1/100秒"
        case .deciseconds: "1/10秒"
        case .seconds: "秒まで"
        }
    }

    var maxPrecision: Duration {
        switch self {
        case .centiseconds: .milliseconds(10)
        case .deciseconds: .milliseconds(100)
        case .seconds: .seconds(1)
        }
    }
}
