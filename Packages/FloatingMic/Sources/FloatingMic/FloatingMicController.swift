import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "FloatingMic")

/// Owns floating-mic interaction state. The `onTap` closure fires whenever the
/// button is pressed — wire this to the voice agent's `toggle()`.
@MainActor
public final class FloatingMicController {
    public var onTap: (() -> Void)?

    public init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    public func tap() {
        logger.info("tap")
        onTap?()
    }
}
