import Foundation
import Testing

struct ClockMathTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ h: Int, _ m: Int, _ s: Int, _ ns: Int = 0, day: Int = 15) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 11, day: day,
                                        hour: h, minute: m, second: s, nanosecond: ns))!
    }

    @Test func 時分秒と100分の1秒に分解() {
        let p = ClockMath.parts(of: date(12, 34, 56, 789_000_000), calendar: tokyo)
        #expect(p == ClockParts(hour: 12, minute: 34, second: 56, centisecond: 78))
        #expect(p.main == "12:34:56")
        #expect(p.fraction == ".78")
    }

    @Test func 一桁の時刻はゼロで埋める() {
        let p = ClockMath.parts(of: date(9, 5, 3, 40_000_000), calendar: tokyo)
        #expect(p.main == "09:05:03")
        #expect(p.fraction == ".04")
    }

    @Test func 秒が変わる直前は99で止まり繰り上がらない() {
        let p = ClockMath.parts(of: date(9, 5, 3, 999_999_000), calendar: tokyo)
        #expect(p.second == 3)
        #expect(p.centisecond == 99)
    }

    @Test(arguments: [0.0, 0.5, -0.5, 3.25])
    func ストップウォッチ開始時刻から補正済みの現在時刻が出る(offset: Double) {
        let systemNow = date(12, 0, 0)
        let start = ClockMath.stopwatchStart(systemNow: systemNow, offset: offset, calendar: tokyo)
        let shown = systemNow.timeIntervalSince(start) // OS が表示する経過秒
        let expected = systemNow.addingTimeInterval(offset).timeIntervalSince(date(0, 0, 0))
        #expect(abs(shown - expected) < 1e-6)
    }

    @Test func 補正で日付をまたぐ時は翌日の0時を基準にする() {
        let systemNow = date(23, 59, 59, 800_000_000)
        let start = ClockMath.stopwatchStart(systemNow: systemNow, offset: 0.5, calendar: tokyo)
        let shown = systemNow.timeIntervalSince(start)
        #expect(abs(shown - 0.3) < 1e-6)
    }
}
