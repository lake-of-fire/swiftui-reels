@preconcurrency import AVFoundation
import Foundation
import HaishinKit
import RTMPHaishinKit
import VideoToolbox

@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class RTMPStreaming: ObservableObject {
    private struct StreamContext {
        let settings: LivestreamSettings
        let connection: RTMPConnection
        let stream: RTMPStream
    }

    private enum Track {
        static let stream: UInt8 = UInt8.max
    }

    public var renderSettings: RenderSettings
    @Published public private(set) var isStreaming: Bool = false

    private var mixer: MediaMixer?
    private var streamContexts: [StreamContext] = []

    public init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }

    public func startStreaming() async {
        guard !isStreaming,
              let livestreamSettings = renderSettings.livestreamSettings,
              !livestreamSettings.isEmpty else {
            return
        }

        let mixer = MediaMixer(captureSessionMode: .manual)
        self.mixer = mixer

        do {
            try await configureMixer(mixer, with: livestreamSettings)
            try await mixer.setFrameRate(Float64(renderSettings.fps))
            await mixer.startRunning()
            self.isStreaming = true
            await publishStreams()
        } catch {
            LoggerHelper.shared.error("Failed to start live streaming: \(error)")
            await teardownStreaming()
        }
    }

    public func stopStreaming() async {
        guard isStreaming else { return }
        await teardownStreaming()
    }

    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard isStreaming, let mixer else { return }
        await mixer.append(sampleBuffer, track: Track.stream)
    }

    private func configureMixer(_ mixer: MediaMixer, with livestreamSettings: [LivestreamSettings]) async throws {
        streamContexts.removeAll()

        for settings in livestreamSettings {
            let connection = RTMPConnection()
            let stream = RTMPStream(connection: connection)

            try await configureStream(stream, with: settings)
            await mixer.addOutput(stream)

            streamContexts.append(StreamContext(settings: settings, connection: connection, stream: stream))
        }
    }

    private func configureStream(_ stream: RTMPStream, with settings: LivestreamSettings) async throws {
        let videoSettings = VideoCodecSettings(
            videoSize: CGSize(width: renderSettings.width, height: renderSettings.height),
            bitRate: settings.bitRate ?? renderSettings.getDefaultBitrate(),
            profileLevel: settings.profileLevel ?? kVTProfileLevel_H264_Main_AutoLevel as String,
            scalingMode: .trim,
            bitRateMode: .average,
            maxKeyFrameIntervalDuration: 2
        )

        let audioSettings = AudioCodecSettings(
            bitRate: 128_000,
            format: .aac
        )

        try await stream.setVideoSettings(videoSettings)
        try await stream.setAudioSettings(audioSettings)
    }

    private func publishStreams() async {
        for context in streamContexts {
            do {
                _ = try await context.connection.connect(context.settings.rtmpConnection)
                try await context.stream.publish(context.settings.streamKey)
            } catch {
                LoggerHelper.shared.error("Failed to publish RTMP stream to \(context.settings.rtmpConnection): \(error)")
            }
        }
    }

    private func teardownStreaming() async {
        self.isStreaming = false

        let contexts = streamContexts
        streamContexts.removeAll()

        if let mixer {
            for context in contexts {
                await mixer.removeOutput(context.stream)
            }
            await mixer.stopRunning()
        }
        mixer = nil

        for context in contexts {
            _ = try? await context.stream.close()
            try? await context.connection.close()
        }
    }
}
