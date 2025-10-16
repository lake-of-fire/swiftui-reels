import AVFoundation
import AVKit
import Foundation
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
public struct SwiftUIReel<Content: View>: View {
    @StateObject private var recorder: Recorder
    @Binding private var renderedVideoData: Data?

    private let previewScale: CGFloat

    @State private var playbackPlayer: AVPlayer?
    @State private var isPlaybackReady = false
    @State private var playbackObserver: Any?

    public var recorderReference: Recorder { recorder }

    @MainActor
    public init(
        fps: Int32,
        width: CGFloat,
        height: CGFloat,
        displayScale: CGFloat,
        captureDuration: Duration? = nil,
        saveVideoFile: Bool = false,
        livestreamSettings: [LivestreamSettings]? = nil,
        previewScale: CGFloat = 1.0,
        renderedVideoData: Binding<Data?> = .constant(nil),
        @ViewBuilder content: @escaping () -> Content
    ) {
        func getTypeName(of view: Content) -> String {
            let mirror = Mirror(reflecting: view)
            return String(describing: mirror.subjectType)
        }

        self.previewScale = previewScale
        self._renderedVideoData = renderedVideoData

        let view = content()
        let viewTypeName = getTypeName(of: view)

        let renderSettings = RenderSettings(
            name: viewTypeName,
            width: Int(width),
            height: Int(height),
            fps: fps,
            displayScale: displayScale,
            captureDuration: captureDuration,
            saveVideoFile: saveVideoFile,
            livestreamSettings: livestreamSettings
        )

        let contentView = AnyView(view)
        let recorderInstance = Recorder(renderSettings: renderSettings)
        recorderInstance.setRenderer(view: contentView)

        _recorder = StateObject(wrappedValue: recorderInstance)
    }

    public var body: some View {
        VStack(spacing: 12) {
            previewSurface
            controlRow
        }
        .onChange(of: recorder.state) { newValue in
            if newValue == .recording {
                resetPlayback()
            }
        }
        .onChange(of: recorder.renderedData) { data in
            renderedVideoData = data
        }
        .onChange(of: recorder.finalOutputURL) { url in
            guard let url else { return }
            configurePlayback(with: url)
        }
        .onDisappear {
            resetPlayback()
        }
    }

    private var previewSurface: some View {
        let scale = max(previewScale, 0.01)
        let baseWidth = CGFloat(recorder.renderSettings.width)
        let baseHeight = CGFloat(recorder.renderSettings.height)
        let scaledWidth = baseWidth * scale
        let scaledHeight = baseHeight * scale

        return ZStack {
            if isPlaybackReady, let player = playbackPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(baseWidth / max(baseHeight, 1), contentMode: .fit)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipped()
                    .onAppear {
                        player.play()
                    }
            } else if let content = recorder.renderer?.content {
                content
                    .frame(width: baseWidth, height: baseHeight)
                    .scaleEffect(scale)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipped()
            } else {
                Color.black.opacity(0.05)
                    .frame(width: scaledWidth, height: scaledHeight)
            }

            RecordingStatusBadge(state: recorder.state)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: scaledWidth, height: scaledHeight)
        .background(Color.black.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor(for: recorder.state), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button(action: toggleRecording) {
                Text(recorder.state == .recording || recorder.state == .paused ? "Stop" : "Record")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReelButtonStyle(role: recorder.state == .recording || recorder.state == .paused ? .destructive : .primary))

            Button(action: togglePause) {
                Text(recorder.state == .paused ? "Resume" : "Pause")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReelButtonStyle(role: .secondary))
            .disabled(recorder.state == .idle || recorder.state == .finished)
        }
    }

    private func toggleRecording() {
        switch recorder.state {
        case .idle, .finished:
            recorder.startRecording()
        case .recording, .paused:
            recorder.stopRecording()
        }
    }

    private func togglePause() {
        switch recorder.state {
        case .recording:
            recorder.pauseRecording()
        case .paused:
            recorder.resumeRecording()
        default:
            break
        }
    }

    private func configurePlayback(with url: URL) {
        resetPlayback()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none

        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }

        playbackPlayer = player
        playbackObserver = observer
        isPlaybackReady = true
        playbackPlayer?.play()
    }

    private func resetPlayback() {
        playbackPlayer?.pause()
        playbackPlayer = nil
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackObserver = nil
        }
        isPlaybackReady = false
    }

    private func borderColor(for state: Recorder.RecordingState) -> Color {
        switch state {
        case .recording:
            return .red
        case .paused:
            return .orange
        case .finished:
            return .green
        case .idle:
            return Color.gray.opacity(0.4)
        }
    }

    deinit {
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RecordingStatusBadge: View {
    let state: Recorder.RecordingState

    var body: some View {
        switch state {
        case .recording:
            label("Recording", color: .red)
        case .paused:
            label("Paused", color: .orange)
        case .finished:
            label("Ready", color: .green)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func label(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.85))
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct ReelButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case destructive
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(8)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return .blue
        case .secondary:
            return .gray
        case .destructive:
            return .red
        }
    }
}
