import Foundation

struct ClockParts: Equatable, Sendable {
    var hour: Int
    var minute: Int
    var second: Int
    var centisecond: Int

    /// "12:34:56"
    var main: String { String(format: "%02d:%02d:%02d", hour, minute, second) }
    /// ".78"
    var fraction: String { String(format: ".%02d", centisecond) }
}

enum ClockMath {
    /// 表示用に時・分・秒・1/100 秒へ分解する（1/100 秒は切り捨て）。
    static func parts(of date: Date, calendar: Calendar = .current) -> ClockParts {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return ClockParts(
            hour: c.hour ?? 0,
            minute: c.minute ?? 0,
            second: c.second ?? 0,
            // Date は内部が小数なので 0.04 秒が 0.0399999… になることがある。
            // マイクロ秒に丸めてから 1/100 秒に切り捨てる。
            centisecond: min(99, ((c.nanosecond ?? 0) + 500) / 1_000 / 10_000)
        )
    }

    /// Dynamic Island 用。
    /// 「この時刻からストップウォッチを始める」と、OS が数える経過時間が
    /// ちょうど「補正済みの現在時刻（0 時からの経過）」になる時刻を返す。
    ///   表示 = 端末の今 − 開始 = (端末の今 + offset) − 補正済みの今日 0 時
    static func stopwatchStart(systemNow: Date, offset: TimeInterval,
                               calendar: Calendar = .current) -> Date {
        let corrected = systemNow.addingTimeInterval(offset)
        return calendar.startOfDay(for: corrected).addingTimeInterval(-offset)
    }
}
