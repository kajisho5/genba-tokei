import AVKit
import Observation
import SwiftUI

/// 小窓（ピクチャ・イン・ピクチャ）の開始・終了
@MainActor
@Observable
final class PiPController: NSObject {
    let renderer = PiPRenderer()
    private(set) var isActive = false
    private(set) var isPossible = false
    private(set) var message: String?
    @ObservationIgnored private var controller: AVPictureInPictureController?
    @ObservationIgnored private var possibleObservation: NSKeyValueObservation?

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    /// 小窓の元になる表示が画面に出た時に呼ぶ
    func prepare() {
        guard controller == nil else { return }
        guard isSupported else {
            message = "この端末は小窓（ピクチャ・イン・ピクチャ）に対応していません"
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)

        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: renderer.layer, playbackDelegate: self
        )
        let c = AVPictureInPictureController(contentSource: source)
        c.delegate = self
        c.requiresLinearPlayback = true
        controller = c
        possibleObservation = c.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] c, _ in
            let possible = c.isPictureInPicturePossible
            Task { @MainActor in self?.isPossible = possible }
        }
        renderer.start()
    }

    func toggle() {
        guard let controller else {
            prepare()
            message = "準備中です。もう一度押してください"
            return
        }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            message = nil
        } else {
            message = "準備中です。少し待ってからもう一度押してください"
        }
    }

    fileprivate func setActive(_ active: Bool) { isActive = active }
    fileprivate func setMessage(_ text: String?) { message = text }
}

extension PiPController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in self.setActive(true) }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in self.setActive(false) }
    }

    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController,
                                                failedToStartPictureInPictureWithError error: Error) {
        let text = "小窓を開けませんでした：\(error.localizedDescription)"
        Task { @MainActor in self.setMessage(text) }
    }
}

extension PiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    // 時計は「生放送」と同じ扱い：一時停止・早送りなし
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }

    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController,
                                                didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController,
                                                skipByInterval skipInterval: CMTime,
                                                completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

/// 小窓の元になる表示（画面にも小さなプレビューとして出す）
struct PiPSourceView: UIViewRepresentable {
    let controller: PiPController

    func makeUIView(context: Context) -> LayerHostView {
        let v = LayerHostView()
        v.isUserInteractionEnabled = false
        v.hosted = controller.renderer.layer
        v.layer.addSublayer(controller.renderer.layer)
        controller.prepare()
        return v
    }

    func updateUIView(_ uiView: LayerHostView, context: Context) {}

    final class LayerHostView: UIView {
        var hosted: CALayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            hosted?.frame = bounds
        }
    }
}
