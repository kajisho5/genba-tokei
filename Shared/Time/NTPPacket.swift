import Foundation

/// NTP（ネットで正確な時刻を取る仕組み）の 48 バイトの電文を作る・読む。
/// 通信はしない純粋な計算だけなので、自動テストで確かめられる。
enum NTPPacket {
    /// NTP の時刻は 1900 年 1 月 1 日起点。Unix 時刻（1970 年起点）との差。
    static let epochDelta: Double = 2_208_988_800
    static let size = 48

    /// Date → NTP の 64 ビット時刻（上位 32 ビット＝秒、下位 32 ビット＝秒の端数）
    static func timestamp(from date: Date) -> UInt64 {
        let t = date.timeIntervalSince1970 + epochDelta
        let seconds = t.rounded(.down)
        let fraction = ((t - seconds) * 4_294_967_296.0).rounded(.down)
        let s = UInt64(max(0, min(seconds, 4_294_967_295)))
        let f = UInt64(max(0, min(fraction, 4_294_967_295)))
        return (s << 32) | f
    }

    /// NTP の 64 ビット時刻 → Date
    static func date(from timestamp: UInt64) -> Date {
        let seconds = Double(timestamp >> 32)
        let fraction = Double(timestamp & 0xFFFF_FFFF) / 4_294_967_296.0
        return Date(timeIntervalSince1970: seconds - epochDelta + fraction)
    }

    /// 問い合わせ電文。送信時刻を入れておき、返事の「元の送信時刻」欄と照合して
    /// 古い返事・なりすましの返事を捨てる。
    static func request(transmit: Date) -> (bytes: [UInt8], transmitTimestamp: UInt64) {
        var bytes = [UInt8](repeating: 0, count: size)
        bytes[0] = 0x23 // LI=0, バージョン=4, モード=3（クライアント）
        let ts = timestamp(from: transmit)
        write(ts, into: &bytes, at: 40)
        return (bytes, ts)
    }

    struct Response: Equatable {
        var stratum: UInt8
        var receive: Date   // サーバーが受け取った時刻 t2
        var transmit: Date  // サーバーが送り返した時刻 t3
    }

    enum ParseError: Error, Equatable {
        case tooShort, notServerMode, unsynchronized, badStratum, originateMismatch
    }

    static func parse(_ bytes: [UInt8], expectedOriginate: UInt64) throws(ParseError) -> Response {
        guard bytes.count >= size else { throw .tooShort }
        let leap = bytes[0] >> 6
        let mode = bytes[0] & 0x07
        guard mode == 4 else { throw .notServerMode }
        guard leap != 3 else { throw .unsynchronized }
        let stratum = bytes[1]
        guard (1...15).contains(stratum) else { throw .badStratum }
        guard read(bytes, at: 24) == expectedOriginate else { throw .originateMismatch }
        return Response(
            stratum: stratum,
            receive: date(from: read(bytes, at: 32)),
            transmit: date(from: read(bytes, at: 40))
        )
    }

    static func write(_ value: UInt64, into bytes: inout [UInt8], at offset: Int) {
        for i in 0..<8 {
            bytes[offset + i] = UInt8(truncatingIfNeeded: value >> (56 - 8 * UInt64(i)))
        }
    }

    static func read(_ bytes: [UInt8], at offset: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(bytes[offset + i]) }
        return v
    }
}

/// 1 回分の測定結果。
/// t1＝送信（端末の時計） t2＝サーバー受信 t3＝サーバー送信 t4＝受信（端末の時計）
struct NTPSample: Equatable {
    var offset: TimeInterval  // 端末の時計に足すと正しい時刻になる量
    var delay: TimeInterval   // 往復の通信時間（サーバー内の処理時間は除く）

    init(t1: Date, t2: Date, t3: Date, t4: Date) {
        let a = t2.timeIntervalSince(t1)
        let b = t3.timeIntervalSince(t4)
        offset = (a + b) / 2
        delay = t4.timeIntervalSince(t1) - t3.timeIntervalSince(t2)
    }

    /// 誤差の目安（±）。往復時間の半分。
    var accuracy: TimeInterval { max(0, delay) / 2 }
}
