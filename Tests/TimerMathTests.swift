import Foundation
import Testing

struct TimerMathTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func カウントダウンの色の段階() {
        var c = CountdownState()
        #expect(c.level(at: t0) == .idle)
        c.set(target: t0.addingTimeInterval(600), now: t0)
        #expect(c.level(at: t0) == .normal)
        #expect(c.level(at: t0.addingTimeInterval(300)) == .warning)   // 残り 5 分ちょうど
        #expect(c.level(at: t0.addingTimeInterval(540)) == .danger)    // 残り 1 分ちょうど
        #expect(c.level(at: t0.addingTimeInterval(600)) == .done)
        #expect(c.remaining(at: t0.addingTimeInterval(700)) == 0)
    }

    @Test func カウントダウンに時間を足す() {
        var c = CountdownState()
        c.add(seconds: 300, now: t0)
        #expect(c.target == t0.addingTimeInterval(300))
        c.add(seconds: 60, now: t0.addingTimeInterval(10))           // 動いている間は残りに足す
        #expect(c.target == t0.addingTimeInterval(360))
        c.add(seconds: 60, now: t0.addingTimeInterval(1000))         // 終わった後は今から
        #expect(c.target == t0.addingTimeInterval(1060))
        #expect(abs(c.progress(at: t0.addingTimeInterval(1030)) - 0.5) < 1e-9)
    }

    @Test func ストップウォッチの開始停止とラップ() {
        var s = StopwatchState()
        s.start(at: t0)
        s.lap(at: t0.addingTimeInterval(10))
        s.stop(at: t0.addingTimeInterval(15))
        #expect(!s.isRunning)
        #expect(s.elapsed(at: t0.addingTimeInterval(100)) == 15)      // 止めている間は進まない
        s.start(at: t0.addingTimeInterval(100))
        s.lap(at: t0.addingTimeInterval(130))
        #expect(s.laps == [10, 35])
        #expect(s.virtualStart == t0.addingTimeInterval(85))
        #expect(s.fastestAndSlowest! == (0, 1))
        s.reset()
        #expect(s == StopwatchState())
    }

    @Test func 時間の表示() {
        #expect(DurationText.parts(207.41) == ("03:27", ".41"))
        #expect(DurationText.parts(3723.5) == ("1:02:03", ".50"))
        #expect(DurationText.parts(-5) == ("00:00", ".00"))
        // 残り 0.001 秒は「00:00.01」と出し、0 になった瞬間に 00:00.00
        #expect(DurationText.countdownParts(0.001) == ("00:00", ".01"))
        #expect(DurationText.countdownParts(0) == ("00:00", ".00"))
    }
}

struct WatchMessageTests {
    @Test func 辞書にして戻しても同じ() {
        let m = WatchMessage(offset: 0.142, accuracyMs: 12, syncedAt: Date(timeIntervalSince1970: 1_800_000_000),
                             countdownLabel: "本番", countdownTarget: Date(timeIntervalSince1970: 1_800_001_500))
        #expect(WatchMessage(dictionary: m.dictionary) == m)
        let empty = WatchMessage(offset: 0, accuracyMs: nil, syncedAt: nil, countdownLabel: "本番", countdownTarget: nil)
        #expect(WatchMessage(dictionary: empty.dictionary) == empty)
        #expect(WatchMessage(dictionary: [:]) == nil)
    }
}
