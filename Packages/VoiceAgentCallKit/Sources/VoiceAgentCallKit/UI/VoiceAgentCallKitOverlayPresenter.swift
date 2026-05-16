import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgentCallKit.Presenter")

/// Window-level overlay for the CallKit-backed voice agent. Mirrors
/// `VoiceAgentOverlayPresenter` — sits in its own `UIWindow` above the main
/// scene so it survives tab switches while a call is active.
@MainActor
public final class VoiceAgentCallKitOverlayPresenter {
    public let controller: VoiceAgentCallKitController

    public init(controller: VoiceAgentCallKitController) {
        self.controller = controller
    }

    public func attach(to scene: UIWindowScene) {
        guard window == nil else { return }
        let overlayWindow = UIWindow(windowScene: scene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        let host = UIHostingController(rootView: VoiceAgentCallKitOverlayView(model: controller))
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
                self.window?.isHidden = !self.controller.visible
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }
}
