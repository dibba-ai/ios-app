import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceCapture.Presenter")

/// Window-level overlay that survives tab switches. Mounts a separate `UIWindow`
/// above the main window. While visible, captures all touches — the user drives
/// the recorder via the overlay's own controls (Stop / Play / Discard).
@MainActor
public final class VoiceCaptureOverlayPresenter {
    public let model: VoiceCaptureOverlayModel

    public init(model: VoiceCaptureOverlayModel) {
        self.model = model
    }

    public func attach(to scene: UIWindowScene) {
        guard window == nil else { return }
        let overlayWindow = UIWindow(windowScene: scene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        let host = UIHostingController(rootView: VoiceCaptureOverlayView(model: model))
        host.view.backgroundColor = .clear
        overlayWindow.rootViewController = host
        overlayWindow.isHidden = true
        self.window = overlayWindow
        observeVisibility()
    }

    public func detach() {
        observationTask?.cancel()
        observationTask = nil
        window?.isHidden = true
        window = nil
    }

    private var window: UIWindow?
    private var observationTask: Task<Void, Never>?

    private func observeVisibility() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.window?.isHidden = !self.model.visible
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }
}
