import Clocks
import CoreMedia
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class ControlledClock {
    public var elapsedTime: TimeInterval = 0
    public var clock: TestClock<Duration>

    public init() {
        self.clock = TestClock()
    }

    public func advance(by duration: Duration) async {
        elapsedTime += duration.inMilliseconds
        await clock.advance(by: duration)
    }

    public func reset() {
        elapsedTime = 0
        clock = TestClock()
    }

    public func sleep(for seconds: Double) async throws {
        try await clock.sleep(for: .seconds(seconds))
    }
}
