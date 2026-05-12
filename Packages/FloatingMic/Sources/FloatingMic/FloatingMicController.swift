import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "FloatingMic")

/// Owns floating-mic interaction state.
/// Future: drive voice recording from any place that embeds a mic affordance.
@MainActor
public final class FloatingMicController {
    public init() {}

    public func tap() {
        logger.info("tap")
    }
}
