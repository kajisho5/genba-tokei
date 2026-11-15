import Foundation
import Testing

struct NTPPacketTests {
    @Test func 時刻の変換を往復しても誤差1マイクロ秒未満() {
        let date = Date(timeIntervalSince1970: 1_794_700_000.123_456)
        let back = NTPPacket.date(from: NTPPacket.timestamp(from: date))
        #expect(abs(back.timeIntervalSince(date)) < 0.000_001)
    }

    @Test func 問い合わせ電文の形() {
        let req = NTPPacket.request(transmit: Date(timeIntervalSince1970: 1_794_700_000))
        #expect(req.bytes.count == 48)
        #expect(req.bytes[0] & 0x07 == 3)        // クライアント
        #expect((req.bytes[0] >> 3) & 0x07 == 4) // バージョン 4
        #expect(NTPPacket.read(req.bytes, at: 40) == req.transmitTimestamp)
    }

    private func makeResponse(originate: UInt64, mode: UInt8 = 4, stratum: UInt8 = 2,
                              receive: Date, transmit: Date) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 48)
        b[0] = (4 << 3) | mode
        b[1] = stratum
        NTPPacket.write(originate, into: &b, at: 24)
        NTPPacket.write(NTPPacket.timestamp(from: receive), into: &b, at: 32)
        NTPPacket.write(NTPPacket.timestamp(from: transmit), into: &b, at: 40)
        return b
    }

    @Test func 正しい返事を読める() throws {
        let t2 = Date(timeIntervalSince1970: 1_794_700_010.25)
        let t3 = Date(timeIntervalSince1970: 1_794_700_010.26)
        let bytes = makeResponse(originate: 42, receive: t2, transmit: t3)
        let r = try NTPPacket.parse(bytes, expectedOriginate: 42)
        #expect(r.stratum == 2)
        #expect(abs(r.receive.timeIntervalSince(t2)) < 0.000_001)
        #expect(abs(r.transmit.timeIntervalSince(t3)) < 0.000_001)
    }

    @Test func 照合番号が違う返事は捨てる() {
        let now = Date()
        let bytes = makeResponse(originate: 1, receive: now, transmit: now)
        #expect(throws: NTPPacket.ParseError.originateMismatch) {
            try NTPPacket.parse(bytes, expectedOriginate: 2)
        }
    }

    @Test func サーバー以外の返事や短い電文は捨てる() {
        let now = Date()
        #expect(throws: NTPPacket.ParseError.notServerMode) {
            try NTPPacket.parse(makeResponse(originate: 1, mode: 3, receive: now, transmit: now), expectedOriginate: 1)
        }
        #expect(throws: NTPPacket.ParseError.badStratum) {
            try NTPPacket.parse(makeResponse(originate: 1, stratum: 0, receive: now, transmit: now), expectedOriginate: 1)
        }
        #expect(throws: NTPPacket.ParseError.tooShort) {
            try NTPPacket.parse([0x24], expectedOriginate: 1)
        }
    }

    @Test func ずれ量と往復時間の計算() {
        // 端末が 10 秒遅れていて、片道 0.1 秒・サーバー処理 0.1 秒の場合
        let base = Date(timeIntervalSince1970: 1_794_700_000)
        let s = NTPSample(
            t1: base,
            t2: base.addingTimeInterval(10.1),
            t3: base.addingTimeInterval(10.2),
            t4: base.addingTimeInterval(0.3)
        )
        // Date の内部表現（2001 年起点の秒の小数）では 1e-7 秒程度の誤差が出るため 1μs で比べる
        #expect(abs(s.offset - 10.0) < 1e-6)
        #expect(abs(s.delay - 0.2) < 1e-6)
        #expect(abs(s.accuracy - 0.1) < 1e-6)
    }
}
