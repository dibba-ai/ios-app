import Dependencies
import Foundation
import Servicing
import SwiftUI
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "SubscriptionActivation")

/// Polls the server until the user's profile reflects premium status, then
/// shows a celebration UI. Presented as a full-screen cover *after* the
/// paywall sheet closes — RevenueCatUI auto-dismisses its host sheet on
/// purchase, so this view must live one level up.
public struct SubscriptionActivationView: View {
    public let onSuccess: () -> Void
    public let onClose: () -> Void

    /// Total polling timeout before giving up.
    public var timeout: TimeInterval = 60
    /// Delay between profile refresh attempts.
    public var pollInterval: TimeInterval = 2

    public init(
        onSuccess: @escaping () -> Void,
        onClose: @escaping () -> Void,
        timeout: TimeInterval = 60,
        pollInterval: TimeInterval = 2
    ) {
        self.onSuccess = onSuccess
        self.onClose = onClose
        self.timeout = timeout
        self.pollInterval = pollInterval
    }

    @State private var phase: Phase = .polling
    @State private var confettiTrigger = 0
    @State private var restoreInProgress = false

    @Dependency(\.profileService) private var profileService
    @Dependency(\.paywallService) private var paywallService

    enum Phase: Equatable { case polling, success, failed }

    public var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            if phase == .success {
                ConfettiView(trigger: confettiTrigger)
                    .allowsHitTesting(false)
            }
        }
        .task { await poll() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .polling:
            VStack(spacing: 20) {
                ProgressView().scaleEffect(1.6)
                Text("Activating your subscription…")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("This usually takes a few seconds.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .success:
            VStack(spacing: 20) {
                Text("⭐️")
                    .font(.system(size: 96))
                Text("Premium activated!")
                    .font(.title.weight(.bold))
                Text("Welcome aboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .failed:
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("Activation taking longer than expected")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Your purchase may have succeeded but Premium hasn't appeared on your account yet. Tap below to restore.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await restoreAndRepoll() }
                } label: {
                    if restoreInProgress {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Restore Purchases")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(restoreInProgress)

                Button("Close") { onClose() }
                    .buttonStyle(.borderless)
                    .disabled(restoreInProgress)
            }
        }
    }

    private func poll() async {
        phase = .polling
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            do {
                let profile = try await profileService.getProfile(force: true)
                if profile.isPremium {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    phase = .success
                    confettiTrigger += 1
                    try? await Task.sleep(for: .seconds(2.8))
                    onSuccess()
                    return
                }
            } catch {
                logger.warning("profile poll failed: \(error.localizedDescription)")
            }
            try? await Task.sleep(for: .seconds(pollInterval))
            if Task.isCancelled { return }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        phase = .failed
    }

    private func restoreAndRepoll() async {
        restoreInProgress = true
        defer { restoreInProgress = false }
        do {
            _ = try await paywallService.restore()
            await poll()
        } catch {
            logger.error("restore failed: \(error.localizedDescription)")
        }
    }
}
