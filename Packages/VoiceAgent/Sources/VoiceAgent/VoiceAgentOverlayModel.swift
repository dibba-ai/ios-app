import ApiClient
import AVFoundation
import Foundation
import Observation
import os.log

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

    /// Mic level (0…1) used by the edge glow. Not yet sourced from WebRTC stats —
    /// reserved for a follow-up; currently breathes via the glow's internal driver.
    public private(set) var level: Float = 0

    public init(apiClient: any APIClienting, defaultVoice: String = "openai_sage") {
        self.apiClient = apiClient
        self.defaultVoice = defaultVoice
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
        visible = true
        phase = .connecting
        assistantTranscript = ""
        userTranscript = ""
        Task { await self.beginSession() }
    }

    public func stop() {
        cancelTasks()
        realtimeClient?.disconnect()
        realtimeClient = nil
        phase = .idle
        visible = false
    }

    // MARK: - Private

    private let apiClient: any APIClienting
    private let defaultVoice: String
    private var realtimeClient: RealtimeClient?
    private var eventTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?

    private func resolveVoice() async -> String {
        do {
            let profile = try await apiClient.getProfile()
            if let voice = profile.favoriteRealtimeVoice, !voice.isEmpty {
                return voice
            }
        } catch {
            logger.warning("profile fetch failed, using default voice: \(error.localizedDescription)")
        }
        return defaultVoice
    }

    private func beginSession() async {
        let voice = await resolveVoice()
        let session: RealtimeSessionDTO
        do {
            session = try await apiClient.createRealtimeSession(
                input: CreateRealtimeSessionInput(voice: voice)
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
        case .assistantTranscriptDelta(_, let text):
            assistantTranscript += text
        case .assistantTranscriptCompleted(_, let text):
            assistantTranscript = text
        case .userTranscriptCompleted(_, let text):
            userTranscript = text
        case .error(let message):
            fail(with: message)
        case .unknown:
            break
        }
    }

    private func fail(with message: String) {
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
        eventTask = nil
        stateTask = nil
        levelTask = nil
        level = 0
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
