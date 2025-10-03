import AVFoundation
import CoreImage
import CoreVideo
//import HaishinKit
import Metal
import SwiftUI
import VideoToolbox

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class VideoRecorder {
    public var renderSettings: RenderSettings
    weak var parentRecorder: Recorder?

    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let frameStream = FrameStream()
    private var processingTask: Task<Void, Error>?

    init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }

    func setParentRecorder(_ parentRecorder: Recorder) {
        self.parentRecorder = parentRecorder
    }

    func setupVideoInput() {
        guard let assetWriter = parentRecorder?.assetWriter else { return }

        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: renderSettings.getDefaultBitrate(),
            AVVideoMaxKeyFrameIntervalKey: renderSettings.getDefaultKeyframeInterval(),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
            AVVideoQualityKey: 0.85 // High quality (0.0 - 1.0)
        ]

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSettings.width,
            AVVideoHeightKey: renderSettings.height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: renderSettings.width,
            kCVPixelBufferHeightKey as String: renderSettings.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        if let videoInput = videoInput, assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        }
    }

    func startProcessingQueue() {
        processingTask = Task { @MainActor in
            for await videoFrame in self.frameStream.stream {
                guard !Task.isCancelled else { break }
                await self.processFrame(cgImage: videoFrame.image, frameTime: videoFrame.time)
            }
        }
    }

    func waitForProcessingCompletion() async {
        try? await processingTask?.value
    }

    func stopProcessingQueue() {
        frameStream.finish()
    }

    public func appendFrame(cgImage: CGImage, frameTime: CMTime) {
        frameStream.enqueue(cgImage, withTime: frameTime)
    }

    public func processFrame(cgImage: CGImage, frameTime: CMTime) async {
        guard let pixelBuffer = pixelBufferFromCGImage(cgImage, width: renderSettings.width, height: renderSettings.height) else { return }
        if renderSettings.saveVideoFile {
            guard let assetWriter = parentRecorder?.assetWriter, assetWriter.status == .writing else { return }
            guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }
            guard let pixelBufferAdaptor = pixelBufferAdaptor else { return }
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
        }

        guard let sampleBuffer = createCMSampleBuffer(from: pixelBuffer, presentationTime: frameTime) else { return }

        if let recorder = parentRecorder {
            await recorder.rtmpStreaming.appendSampleBuffer(sampleBuffer)
        }
    }
}
