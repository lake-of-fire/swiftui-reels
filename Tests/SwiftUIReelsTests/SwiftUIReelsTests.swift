import SwiftUI
import VideoViews
import XCTest
@testable import SwiftUIReels

@MainActor
final class SwiftUIReelsTests: XCTestCase {
    func testBasicCounterViewProducesRecording() async throws {
        let recorder = createSwiftUIReelRecorder(
            fps: 30,
            width: 720,
            height: 1280,
            displayScale: 2.0,
            captureDuration: .seconds(2),
            saveVideoFile: true,
            audioEnabled: false
        ) {
            BasicCounterView(initialCounter: 0)
        }

        recorder.startRecording()
        await recorder.waitForRecordingCompletion()

        let outputURL = recorder.renderSettings.outputURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "Expected video file to exist at \(outputURL)")

        let attachment = XCTAttachment(contentsOfFile: outputURL)
        attachment.name = "BasicCounterRecording.mp4"
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(attachment)
    }

    func testRecorderProducesDataWithoutSavingFile() async throws {
        let recorder = createSwiftUIReelRecorder(
            fps: 24,
            width: 540,
            height: 960,
            displayScale: 2.0,
            captureDuration: .seconds(1),
            saveVideoFile: false,
            audioEnabled: false
        ) {
            BasicCounterView(initialCounter: 0)
        }

        recorder.startRecording()
        await recorder.waitForRecordingCompletion()

        XCTAssertNotNil(recorder.renderedData, "Recorder should expose rendered video data when not saving to disk")
        if let finalURL = recorder.finalOutputURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path), "Expected temporary video file to exist at \(finalURL)")
        } else {
            XCTFail("Recorder should provide a final output URL even when not saving to disk")
        }
    }
}
