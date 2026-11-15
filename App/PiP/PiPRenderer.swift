import AVFoundation
import CoreMedia
import UIKit

/// 小窓（ピクチャ・イン・ピクチャ）に流す「時計の映像」を作り続ける。
/// 1 秒に 60 コマ、時計の絵を描いて AVSampleBufferDisplayLayer に渡す。
final class PiPRenderer: @unchecked Sendable {
    struct Snapshot: Sendable {
        var offset: TimeInterval = 0
        var countdownLabel: String?
        var countdownTarget: Date?   // 補正済みの時刻
        var showsFraction = true
        var syncOK = false
    }

    let layer = AVSampleBufferDisplayLayer()
    let size = CGSize(width: 720, height: 360)

    private let queue = DispatchQueue(label: "genba.pip.render", qos: .userInteractive)
    private let lock = NSLock()
    private var snapshot = Snapshot()
    private var timer: DispatchSourceTimer?
    private var pool: CVPixelBufferPool?

    init() {
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = UIColor.black.cgColor
    }

    func update(_ s: Snapshot) { lock.withLock { snapshot = s } }

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: .nanoseconds(16_666_667), leeway: .milliseconds(2))
            t.setEventHandler { [weak self] in self?.renderFrame() }
            t.resume()
            timer = t
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
        }
    }

    // MARK: 描画

    private func renderFrame() {
        let s = lock.withLock { snapshot }
        guard let buffer = makePixelBuffer() else { return }
        draw(s, into: buffer)
        guard let sample = makeSampleBuffer(buffer) else { return }
        let renderer = layer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        if renderer.isReadyForMoreMediaData { renderer.enqueue(sample) }
    }

    private func makePixelBuffer() -> CVPixelBuffer? {
        if pool == nil {
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ]
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private func draw(_ s: Snapshot, into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        ctx.setFillColor(UIColor(red: 0.043, green: 0.051, blue: 0.063, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // UIKit の文字描画は上下が逆なので反転する
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }

        let now = Date().addingTimeInterval(s.offset)
        let p = ClockMath.parts(of: now)
        let white = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
        let amber = UIColor(red: 1, green: 0.69, blue: 0.125, alpha: 1)
        let gray = UIColor(red: 0.54, green: 0.57, blue: 0.61, alpha: 1)

        // 状態の点
        ctx.setFillColor((s.syncOK ? UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1) : UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 1)).cgColor)
        ctx.fillEllipse(in: CGRect(x: 32, y: 30, width: 16, height: 16))

        let hasCountdown = s.countdownTarget != nil
        let clock = NSMutableAttributedString(string: p.main, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: hasCountdown ? 120 : 140, weight: .semibold),
            .foregroundColor: white,
        ])
        if s.showsFraction {
            clock.append(NSAttributedString(string: p.fraction, attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: hasCountdown ? 78 : 90, weight: .semibold),
                .foregroundColor: amber,
            ]))
        }
        let cs = clock.size()
        let clockY = hasCountdown ? 70.0 : (CGFloat(h) - cs.height) / 2
        clock.draw(at: CGPoint(x: (CGFloat(w) - cs.width) / 2, y: clockY))

        if let target = s.countdownTarget {
            let remaining = max(0, target.timeIntervalSince(now))
            let r = DurationText.countdownParts(remaining)
            let color = remaining <= 60 ? UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 1)
                : remaining <= 300 ? UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1) : gray
            let line = NSAttributedString(string: "\(s.countdownLabel ?? "本番")まで −\(r.main)\(r.fraction)", attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: color,
            ])
            let ls = line.size()
            line.draw(at: CGPoint(x: (CGFloat(w) - ls.width) / 2, y: 240))
        }
    }

    private func makeSampleBuffer(_ buffer: CVPixelBuffer) -> CMSampleBuffer? {
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &format)
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 60),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil, imageBuffer: buffer, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sample
        )
        guard let sample else { return nil }
        // 時刻合わせを待たずにすぐ表示する
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sample
    }
}
