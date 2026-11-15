import Foundation
#if canImport(Darwin)
import Darwin
#endif

struct NTPResult: Sendable, Equatable {
    var offset: TimeInterval
    var accuracy: TimeInterval
    var server: String
    var syncedAt: Date
}

enum NTPError: Error, Sendable {
    case resolveFailed
    case socketFailed
    case noValidResponse
}

/// UDP 123 番で NTP サーバーに数回問い合わせ、往復時間が一番短い回を採用する。
/// iPhone / iPad 用。Apple Watch は OS が UDP 通信を許可しないので使わない（TN3135）。
enum NTPClient {
    static func sync(server: String, samples: Int = 8) async throws -> NTPResult {
        try await Task.detached(priority: .userInitiated) {
            try syncBlocking(server: server, samples: samples)
        }.value
    }

    private static func syncBlocking(server: String, samples: Int) throws -> NTPResult {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP
        var list: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(server, "123", &hints, &list) == 0, let info = list else {
            throw NTPError.resolveFailed
        }
        defer { freeaddrinfo(list) }

        let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
        guard fd >= 0 else { throw NTPError.socketFailed }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 else {
            throw NTPError.socketFailed
        }

        var best: NTPSample?
        for i in 0..<samples {
            let t1 = Date()
            let request = NTPPacket.request(transmit: t1)
            let sent = request.bytes.withUnsafeBytes { send(fd, $0.baseAddress, $0.count, 0) }
            if sent == NTPPacket.size {
                var buffer = [UInt8](repeating: 0, count: 128)
                let received = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
                let t4 = Date()
                if received >= NTPPacket.size,
                   let response = try? NTPPacket.parse(Array(buffer[0..<received]),
                                                       expectedOriginate: request.transmitTimestamp) {
                    let sample = NTPSample(t1: t1, t2: response.receive, t3: response.transmit, t4: t4)
                    if sample.delay >= 0, sample.delay < (best?.delay ?? .infinity) {
                        best = sample
                    }
                }
            }
            if i < samples - 1 { usleep(60_000) }
        }

        guard let best else { throw NTPError.noValidResponse }
        return NTPResult(offset: best.offset, accuracy: best.accuracy, server: server, syncedAt: Date())
    }
}
