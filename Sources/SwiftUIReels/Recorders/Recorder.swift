import AVFoundation
import Combine
import HaishinKit
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class Recorder: ObservableObject {
    public enum RecordingState: Sendable {
        case idle, recording, paused, finished
    }

    private var pauseCounter: Int = 0

    @Published public private(set) var state: RecordingState = .idle
    @Published public private(set) var frameCount: Int = 0
    @Published public private(set) var elapsedTime: TimeInterval = 0

    public var recordingTask: Task<Void, Error>?
    private var streamingTask: Task<Void, Never>?
    private let recordingCompletionContinuation = AsyncStream<Void>.makeStream()

    public var controlledClock: ControlledClock
    public let frameTimer: FrameTimer

    @MainActor public var renderer: ImageRenderer<SizedView<AnyView>>?

    private var videoRecorder: VideoRecorder
    public var audioRecorder: AudioRecorder
    public let rtmpStreaming: RTMPStreaming

    public var renderSettings: RenderSettings
    public var assetWriter: AVAssetWriter?

   private var hud: HUD

    public init(renderSettings: RenderSettings) {
        self.controlledClock = ControlledClock()
        self.frameTimer = FrameTimer(frameRate: Double(renderSettings.fps))

        self.renderSettings = renderSettings
       self.hud = HUD()

        self.videoRecorder = VideoRecorder(renderSettings: renderSettings)
        self.audioRecorder = AudioRecorder(renderSettings: renderSettings, frameTimer: frameTimer)
        self.rtmpStreaming = RTMPStreaming(renderSettings: renderSettings)

        videoRecorder.setParentRecorder(self)
        audioRecorder.setParentRecorder(self)
       hud.setRecorder(recorder: self)
    }

    @MainActor
    public func setRenderer(view: AnyView) {
        let viewWithEnv = AnyView(
            view
                .environmentObject(self)
        )
        renderer = ImageRenderer(
            content: SizedView(
                content: viewWithEnv,
                width: CGFloat(renderSettings.width),
                height: CGFloat(renderSettings.height)
            )
        )
    }

    @MainActor
    public func startRecording() {
        guard state == .idle else { return }

        state = .recording
        frameTimer.start()
        frameCount = 0
        elapsedTime = 0

        setupRecording()
        startRecordingTask()
    }

    public func setupRecording() {
        do {
            assetWriter = try AVAssetWriter(outputURL: renderSettings.tempOutputURL, fileType: .mp4)

            videoRecorder.setupVideoInput()
            if renderSettings.audioEnabled {
                audioRecorder.setupAudioInput()
            }

            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: CMTime.zero)

            videoRecorder.startProcessingQueue()
            if renderSettings.livestreamSettings?.isEmpty == false {
                streamingTask?.cancel()
                streamingTask = Task { @MainActor in
                    await self.rtmpStreaming.startStreaming()
                }
            }
        } catch {
            LoggerHelper.shared.error("Error starting recording: \(error)")
        }
    }

    private func startRecordingTask() {
        recordingTask = Task { @MainActor in
            let clock = ContinuousClock()

            let totalFrames = calculateTotalFrames()
            let frameDuration = Duration.seconds(1) / Int(renderSettings.fps)

            while !Task.isCancelled, state != .finished, self.frameTimer.frameCount < totalFrames {
                switch state {
                case .recording:
                    let start = clock.now

                    captureFrame()

                    await controlledClock.advance(by: frameDuration)
                    self.elapsedTime = self.controlledClock.elapsedTime
                    let end = clock.now
                    let elapsed = end - start
                    let sleepDuration = frameDuration - elapsed

                    if sleepDuration > .zero {
                        try await Task.sleep(for: sleepDuration)
                    }
                    _ = self.hud.render()

                case .paused:
                    _ = self.hud.render()
                    try await Task.sleep(for: frameDuration)

                case .finished, .idle:
                    break
                }
            }

            _ = self.hud.render()
            await finishRecording()
        }
    }

    func finishRecording() async {
        videoRecorder.stopProcessingQueue()
        await videoRecorder.waitForProcessingCompletion()
        if renderSettings.audioEnabled {
            audioRecorder.stopRecording()
        }
        if let streamingTask {
            await streamingTask.value
        }
        await rtmpStreaming.stopStreaming()
        streamingTask = nil

        await finishWriting()
    }

    public func pauseRecording() {
        pauseCounter += 1
        guard state == .recording else { return }
        state = .paused
        audioRecorder.pauseAllAudio()
    }

    public func resumeRecording() {
        pauseCounter -= 1
        guard state == .paused else { return }
        if pauseCounter == 0, state == .paused {
            state = .recording
            audioRecorder.resumeAllAudio()
        }
    }

    public func stopRecording() {
        guard state == .recording || state == .paused else { return }
        audioRecorder.stopRecording()
        state = .finished
    }

    @MainActor
    public func waitForRecordingCompletion() async {
        for await _ in recordingCompletionContinuation.stream {}
    }

    private func finishWriting() async {
        guard renderSettings.saveVideoFile else {
            recordingCompletionContinuation.continuation.finish()
            return
        }

        await assetWriter?.finishWriting()

        guard let tempOutputURL = assetWriter?.outputURL else {
            LoggerHelper.shared.error("No output url")
            recordingCompletionContinuation.continuation.finish()
            return
        }

        if let outputURL = assetWriter?.outputURL, let duration = renderSettings.captureDuration {
            if await trimVideo(at: outputURL, to: duration) != nil {
                try? FileManager.default.removeItem(at: tempOutputURL)
            }
        } else {
            try? FileManager.default.moveItem(at: tempOutputURL, to: renderSettings.outputURL)
        }

        recordingCompletionContinuation.continuation.finish()
    }

    //    Audio
    public func loadAudio(from url: URL) async throws {
        pauseRecording()
        try await audioRecorder.loadAudio(from: url)
        resumeRecording()
    }

    public func playAudio(from url: URL) {
        audioRecorder.playAudio(from: url)
    }

    public func stopAudio(from url: URL) {
        audioRecorder.stopAudio(from: url)
    }

    public func pauseAudio(from url: URL) {
        audioRecorder.pauseAudio(from: url)
    }

    public func resumeAudio(from url: URL) {
        audioRecorder.resumeAudio(from: url)
    }

//    Video

    @MainActor
    private func captureFrame() {
        guard let renderer = renderer else { return }
        renderer.scale = renderSettings.displayScale
        guard let cgImage = renderer.cgImage else { return }

        let frameTime = frameTimer.getCurrentFrameTime()

        videoRecorder.appendFrame(cgImage: cgImage, frameTime: frameTime)

        frameTimer.incrementFrame()
        frameCount = frameTimer.frameCount
    }

    public func calculateTotalFrames() -> Int {
        if let captureDuration = renderSettings.captureDuration {
            return Int(captureDuration.components.seconds) * Int(renderSettings.fps)
        } else {
            return Int.max
        }
    }

    private func trimVideo(at url: URL, to duration: Duration) async -> URL? {
        let asset = AVAsset(url: url)
        let startTime = CMTime.zero
        let endTime = CMTime(seconds: Double(duration.components.seconds), preferredTimescale: 600)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            LoggerHelper.shared.error("Error trimming video - cant AVAssetExportSession")
            return nil
        }

        let trimmedOutputURL = renderSettings.outputURL
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)

        if FileManager.default.fileExists(atPath: trimmedOutputURL.path) {
            try? FileManager.default.removeItem(at: trimmedOutputURL)
        }

        do {
            try await exportSession.export(to: trimmedOutputURL, as: .mp4)
            return trimmedOutputURL
        } catch {
            LoggerHelper.shared.error("Trimming failed: \(error)")
            return nil
        }
    }
}
