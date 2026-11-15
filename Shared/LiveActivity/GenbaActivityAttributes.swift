import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Dynamic Island / ロック画面に渡すデータ（4KB 以内）。
struct GenbaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// ClockMath.stopwatchStart で求めた「ストップウォッチ開始時刻」
        var stopwatchStart: Date
        var precision: DisplayPrecision
        /// NTP の誤差（ミリ秒）。未補正なら nil
        var accuracyMs: Int?
    }
}
#endif

/// 試作で切り替えて比べる表示の細かさ
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
