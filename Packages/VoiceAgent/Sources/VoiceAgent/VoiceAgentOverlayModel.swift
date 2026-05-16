import ApiClient
import AVFoundation
import Foundation
import Observation
import os.log
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgent.Overlay")

/// Top-level state machine for the realtime voice-agent overlay.
///
/// Tap flow (`toggle()`):
/// 1. Visible flips on instantly so the overlay + glow render before any
///    network or mic activity.
/// 2. Creates a realtime session via the backend mutation.
/// 3. On success: requests mic permission, opens WebRTC, switches to `.live`.
/// 4. On failure: surfaces an error pill, auto-dismisses after a short delay.
@MainActor
@Observable
public final class VoiceAgentOverlayModel {
    public enum Phase: Sendable, Equatable {
        case idle
        case connecting
        case requestingPermission
        case live
        case error(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var visible: Bool = false
    public private(set) var assistantTranscript: String = ""
    public private(set) var userTranscript: String = ""
    public var outputTranscriptVisible: Bool = true
    public private(set) var isMuted: Bool = false
    public private(set) var isSpeakerOn: Bool = true
    public private(set) var connectedAt: Date?

    /// Mic level (0…1) used by the edge glow. Not yet sourced from WebRTC stats —
    /// reserved for a follow-up; currently breathes via the glow's internal driver.
    public private(set) var level: Float = 0

    /// Inactivity window before the top transcript banner fades away.
    public var transcriptInactivityTimeout: TimeInterval = 5

    public init(apiClient: any APIClienting, defaultVoice: String = "openai_sage") {
        self.apiClient = apiClient
        self.defaultVoice = defaultVoice
    }

    public func toggleOutputTranscript() {
        outputTranscriptVisible.toggle()
        haptic(.selection)
    }

    public func toggleMute() {
        isMuted.toggle()
        realtimeClient?.setMicMuted(isMuted)
        haptic(.selection)
    }

    public func toggleSpeaker() {
        isSpeakerOn.toggle()
        realtimeClient?.setSpeakerEnabled(isSpeakerOn)
        haptic(.selection)
    }

    /// Single entry point bound to the mic tab tap.
    public func toggle() {
        if visible {
            stop()
        } else {
            show()
        }
    }

    public func show() {
        guard !visible else { return }
        haptic(.lightImpact)
        visible = true
        phase = .connecting
        assistantTranscript = ""
        userTranscript = ""
        currentAssistantItemId = nil
        isMuted = false
        isSpeakerOn = true
        connectedAt = nil
        Task { await self.beginSession() }
    }

    public func stop() {
        haptic(.mediumImpact)
        cancelTasks()
        realtimeClient?.disconnect()
        realtimeClient = nil
        phase = .idle
        visible = false
        connectedAt = nil
    }

    // MARK: - Private

    private let apiClient: any APIClienting
    private let defaultVoice: String
    private var realtimeClient: RealtimeClient?
    private var eventTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var transcriptClearTask: Task<Void, Never>?
    private var currentAssistantItemId: String?

    private func resolvePreferences() async -> (voice: String, vibe: String?) {
        do {
            let profile = try await apiClient.getProfile()
            let voice = (profile.favoriteRealtimeVoice?.isEmpty == false) ? profile.favoriteRealtimeVoice! : defaultVoice
            let vibe = (profile.favoriteVibe?.isEmpty == false) ? profile.favoriteVibe : nil
            return (voice, vibe)
        } catch {
            logger.warning("profile fetch failed, using default voice: \(error.localizedDescription)")
        }
        return (defaultVoice, nil)
    }

    private func beginSession() async {
        let prefs = await resolvePreferences()
        let session: RealtimeSessionDTO
        do {
            session = try await apiClient.createRealtimeSession(
                input: CreateRealtimeSessionInput(voice: prefs.voice, vibe: prefs.vibe)
            )
        } catch {
            logger.error("createRealtimeSession failed: \(error.localizedDescription)")
            fail(with: Self.userFacingMessage(for: error))
            return
        }
        guard let endpoint = URL(string: session.endpoint) else {
            logger.error("invalid endpoint: \(session.endpoint)")
            fail(with: "Voice agent endpoint invalid.")
            return
        }

        phase = .requestingPermission
        let micGranted = await Self.requestMicrophonePermission()
        guard micGranted else {
            logger.warning("mic permission denied")
            fail(with: "Microphone permission denied.")
            return
        }

        let client = RealtimeClient()
        realtimeClient = client
        subscribeToClient(client)
        do {
            try await client.connect(endpoint: endpoint, token: session.token)
        } catch {
            logger.error("WebRTC connect failed: \(error.localizedDescription)")
            fail(with: "Couldn't connect to voice agent.")
            return
        }
        phase = .live
        connectedAt = Date()
        haptic(.success)
    }

    private func subscribeToClient(_ client: RealtimeClient) {
        eventTask?.cancel()
        stateTask?.cancel()
        levelTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in client.events {
                guard let self else { return }
                self.handle(event: event)
            }
        }
        stateTask = Task { [weak self] in
            for await state in client.states {
                guard let self else { return }
                switch state {
                case .failed(let reason):
                    self.fail(with: "Connection lost: \(reason)")
                case .closed:
                    if self.visible { self.stop() }
                default:
                    break
                }
            }
        }
        levelTask = Task { [weak self] in
            for await levels in client.audioLevels {
                self?.level = levels.combined
            }
        }
    }

    private func handle(event: RealtimeEvent) {
        switch event {
        case .assistantTranscriptDelta(let itemId, let text):
            if itemId != currentAssistantItemId {
                currentAssistantItemId = itemId
                assistantTranscript = ""
            }
            assistantTranscript += text
            transcriptClearTask?.cancel()
        case .assistantTranscriptCompleted(let itemId, let text):
            currentAssistantItemId = itemId
            assistantTranscript = text
            transcriptClearTask?.cancel()
        case .audioOutputDone:
            scheduleTranscriptClear()
        case .userTranscriptDelta(_, let text):
            userTranscript += text
        case .userTranscriptCompleted(_, let text):
            userTranscript = text
        case .error(let message):
            fail(with: message)
        case .unknown:
            break
        }
    }

    private func scheduleTranscriptClear() {
        transcriptClearTask?.cancel()
        let timeout = transcriptInactivityTimeout
        transcriptClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard let self, !Task.isCancelled else { return }
            self.assistantTranscript = ""
            self.currentAssistantItemId = nil
        }
    }

    private func fail(with message: String) {
        haptic(.warning)
        cancelTasks()
        realtimeClient?.disconnect()
        realtimeClient = nil
        phase = .error(message)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, case .error = self.phase else { return }
            self.visible = false
            self.phase = .idle
        }
    }

    private func cancelTasks() {
        eventTask?.cancel()
        stateTask?.cancel()
        levelTask?.cancel()
        transcriptClearTask?.cancel()
        eventTask = nil
        stateTask = nil
        levelTask = nil
        transcriptClearTask = nil
        level = 0
    }

    private enum HapticKind {
        case selection
        case lightImpact
        case mediumImpact
        case success
        case warning
    }

    private func haptic(_ kind: HapticKind) {
        switch kind {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .lightImpact:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .mediumImpact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    /// Distil any error from the backend / network into a one-line message we can
    /// show in the status pill. Falls back to a generic message if the error
    /// doesn't carry a human-readable description.
    private static func userFacingMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError, let desc = apiError.errorDescription {
            return desc
        }
        let localised = error.localizedDescription
        if !localised.isEmpty { return localised }
        return "Voice agent unavailable. Try again later."
    }

    private static func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
    }
}
