//
//  File.swift
//
//
//  Created by Jordan Howlett on 6/27/24.
//

import Foundation

public class HUD {
    private weak var recorder: Recorder?
    
    public init() {
    }
    
    public func setRecorder(recorder: Recorder) {
        self.recorder = recorder
    }
    
    public func render() -> String {
        guard let recorder = recorder else {
            let loading = "🌀 Loading"
            print(loading)
            return loading
        }
        let elapsedTime = recorder.controlledClock.elapsedTime
        let elapsedTimeFormatted = formatTimeInterval(elapsedTime)
        let stateEmoji = getStateEmoji(for: recorder.state)
        let frameCount = recorder.frameTimer.frameCount
        let totalFrames = recorder.calculateTotalFrames()
        
        let frameProgress = recorder.renderSettings.captureDuration == nil ? String(frameCount) : "\(frameCount) / \(totalFrames)"
        
        let streamsInfo = recorder.renderSettings.livestreamSettings?.count ?? 0 > 0 ? "📺 LIVE" : "NOT LIVE"
        let outputInfo = recorder.renderSettings.saveVideoFile ? recorder.renderSettings.outputURL.absoluteString : "Not Saving video"
        
        let info = "Time Recording: \(elapsedTimeFormatted)\nFrames Captured: \(frameProgress)\nState: \(stateEmoji)\nOutput URL: \(outputInfo)\n\(streamsInfo)"
        print(info)
        return info
    }
    
    private func getStateEmoji(for state: Recorder.RecordingState) -> String {
        switch state {
        case .recording:
            return "🔴 Recording"
        case .paused:
            return "⏸️ Paused"
        case .finished, .idle:
            return "✅ Finished"
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let intervalInSeconds = interval / 1000 // Convert milliseconds to seconds
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: intervalInSeconds) ?? "00:00:00"
    }
}
