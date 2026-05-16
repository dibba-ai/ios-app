import ApiClient
import AVFoundation
import CallKit
import Core
import Foundation
import Observation
import os.log
import UIKit
import VoiceAgent

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgentCallKit")

/// CallKit-backed voice agent. iOS owns audio session, route picker, lock
/// screen, Dynamic Island, and Phone-app recents. The in-app overlay UI
/// (transcript banner + controls) is presented on top — system call UI is
/// only foregrounded when the user backgrounds the app or locks the device.
@MainActor
@Observable
public final class VoiceAgentCallKitController: NSObject {
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
    public private(set) var level: Float = 0
    public private(set) var voiceEmoji: String?
    public private(set) var displayName: String = "Dibba Voice Agent"
    public var transcriptInactivityTimeout: TimeInterval = 5

    public init(apiClient: any APIClienting, defaultVoice: String = "openai_sage") {
        self.apiClient = apiClient
        self.defaultVoice = defaultVoice

        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = true
        config.ringtoneSound = nil
        self.provider = CXProvider(configuration: config)
        self.callController = CXCallController()
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    public func toggle() {
        if let uuid = currentCallUUID {
            requestEndCall(uuid: uuid)
        } else {
            requestStartCall()
        }
    }

    public func stop() {
        haptic(.mediumImpact)
        if let uuid = currentCallUUID {
            requestEndCall(uuid: uuid)
        }
    }

    public func toggleMute() {
        guard let uuid = currentCallUUID else { return }
        haptic(.selection)
        let newMuted = !isMuted
        let action = CXSetMutedCallAction(call: uuid, muted: newMuted)
        callController.request(CXTransaction(action: action)) { error in
            if let error {
                logger.error("setMuted request failed: \(error.localizedDescription)")
            }
        }
    }

    public func toggleSpeaker() {
        haptic(.selection)
        isSpeakerOn.toggle()
        realtimeClient?.setSpeakerEnabled(isSpeakerOn)
    }

    public func toggleOutputTranscript() {
        haptic(.selection)
        outputTranscriptVisible.toggle()
    }

    // MARK: - Private

    private let apiClient: any APIClienting
    private let defaultVoice: String
    private let provider: CXProvider
    private let callController: CXCallController
    private var currentCallUUID: UUID?
    private var sessionDTO: RealtimeSessionDTO?
    private var realtimeClient: RealtimeClient?
    private var stateTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var transcriptClearTask: Task<Void, Never>?
    private var currentAssistantItemId: String?

    private func requestStartCall() {
        haptic(.lightImpact)
        let uuid = UUID()
        currentCallUUID = uuid
        phase = .connecting
        visible = true
        assistantTranscript = ""
        userTranscript = ""
        currentAssistantItemId = nil
        isMuted = false
        isSpeakerOn = true
        connectedAt = nil
        level = 0
        voiceEmoji = nil
        displayName = "Dibba Voice Agent"

        let handle = CXHandle(type: .generic, value: "dibba.voice")
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = false
        let tx = CXTransaction(action: action)
        callController.request(tx) { [weak self] error in
            if let error {
                logger.error("startCall request failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.handleHardFailure(reason: error.localizedDescription)
                }
            }
            _ = self
        }
    }

    private func requestEndCall(uuid: UUID) {
        let action = CXEndCallAction(call: uuid)
        let tx = CXTransaction(action: action)
        callController.request(tx) { error in
            if let error {
                logger.error("endCall request failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleHardFailure(reason: String) {
        haptic(.warning)
        phase = .error(reason)
        if let uuid = currentCallUUID {
            provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            currentCallUUID = nil
        }
        cancelTasks()
        realtimeClient?.disconnect()
        realtimeClient = nil
        sessionDTO = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, case .error = self.phase else { return }
            self.visible = false
            self.phase = .idle
        }
    }

    private struct ResolvedPreferences {
        let voice: String
        let vibe: String?
        let displayName: String
        let voiceEmoji: String?
    }

    private func resolvePreferences() async -> ResolvedPreferences {
        var voiceId = defaultVoice
        var vibeRaw: String?
        do {
            let profile = try await apiClient.getProfile()
            if let v = profile.favoriteRealtimeVoice, !v.isEmpty { voiceId = v }
            if let vb = profile.favoriteVibe, !vb.isEmpty { vibeRaw = vb }
        } catch {
            logger.warning("profile fetch failed: \(error.localizedDescription)")
        }

        var voiceLabel = voiceId
        var voiceEmoji: String?
        do {
            let options = try await apiClient.getRealtimeOptions()
            if let v = options.voices.first(where: { $0.voice == voiceId }) {
                voiceLabel = v.name
                if let emoji = v.emoji, !emoji.isEmpty { voiceEmoji = emoji }
            }
        } catch {
            logger.warning("realtime options fetch failed: \(error.localizedDescription)")
        }

        let vibeLabel: String?
        if let raw = vibeRaw, let opt = VibeOption(rawValue: raw) {
            vibeLabel = opt.label
        } else {
            vibeLabel = nil
        }

        let displayName: String
        if let vibeLabel {
            displayName = "\(vibeLabel) \(voiceLabel)"
        } else {
            displayName = voiceLabel
        }
        return ResolvedPreferences(voice: voiceId, vibe: vibeRaw, displayName: displayName, voiceEmoji: voiceEmoji)
    }

    private func subscribeToClient(_ client: RealtimeClient, uuid: UUID) {
        cancelTasks()
        eventTask = Task { [weak self, weak client] in
            guard let client else { return }
            for await event in client.events {
                guard let self else { return }
                self.handle(event: event)
            }
        }
        stateTask = Task { [weak self, weak client] in
            guard let client else { return }
            for await state in client.states {
                guard let self else { return }
                if case .failed(let reason) = state {
                    logger.warning("rtc state failed: \(reason)")
                    self.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                    self.requestEndCall(uuid: uuid)
                }
            }
        }
        levelTask = Task { [weak self, weak client] in
            guard let client else { return }
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
            handleHardFailure(reason: message)
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
        case selection, lightImpact, mediumImpact, success, warning
    }

    private func haptic(_ kind: HapticKind) {
        switch kind {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .lightImpact: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .mediumImpact: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

private struct CallKitBox<A>: @unchecked Sendable {
    let provider: CXProvider
    let action: A
}

extension VoiceAgentCallKitController: CXProviderDelegate {
    nonisolated public func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.cancelTasks()
            self.realtimeClient?.disconnect()
            self.realtimeClient = nil
            self.sessionDTO = nil
            self.currentCallUUID = nil
            self.phase = .idle
            self.visible = false
            self.connectedAt = nil
        }
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let box = CallKitBox(provider: provider, action: action)
        Task { @MainActor [weak self] in
            guard let self else { box.action.fail(); return }
            do {
                let prefs = await self.resolvePreferences()
                let session = try await self.apiClient.createRealtimeSession(
                    input: CreateRealtimeSessionInput(voice: prefs.voice, vibe: prefs.vibe)
                )
                self.sessionDTO = session
                self.displayName = prefs.displayName
                self.voiceEmoji = prefs.voiceEmoji

                let update = CXCallUpdate()
                update.localizedCallerName = prefs.displayName
                update.remoteHandle = CXHandle(type: .generic, value: prefs.displayName)
                update.hasVideo = false
                update.supportsHolding = false
                update.supportsGrouping = false
                update.supportsUngrouping = false
                update.supportsDTMF = false
                box.provider.reportCall(with: box.action.callUUID, updated: update)
                box.provider.reportOutgoingCall(with: box.action.callUUID, startedConnectingAt: nil)
                box.action.fulfill()
            } catch {
                logger.error("createRealtimeSession failed: \(error.localizedDescription)")
                box.action.fail()
                self.handleHardFailure(reason: "Couldn't create session.")
            }
        }
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let box = CallKitBox(provider: provider, action: action)
        Task { @MainActor [weak self] in
            guard let self else { box.action.fail(); return }
            self.cancelTasks()
            self.realtimeClient?.disconnect()
            self.realtimeClient = nil
            self.sessionDTO = nil
            self.currentCallUUID = nil
            self.phase = .idle
            self.visible = false
            self.connectedAt = nil
            box.action.fulfill()
        }
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let box = CallKitBox(provider: provider, action: action)
        Task { @MainActor [weak self] in
            guard let self else { box.action.fail(); return }
            self.isMuted = box.action.isMuted
            self.realtimeClient?.setMicMuted(box.action.isMuted)
            box.action.fulfill()
        }
    }

    nonisolated public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let box = CallKitBox(provider: provider, action: ())
        Task { @MainActor [weak self] in
            guard let self,
                  let session = self.sessionDTO,
                  let endpoint = URL(string: session.endpoint),
                  let uuid = self.currentCallUUID else {
                logger.error("didActivate: missing session/endpoint/uuid")
                return
            }
            self.phase = .requestingPermission
            let client = RealtimeClient()
            self.realtimeClient = client
            self.subscribeToClient(client, uuid: uuid)
            do {
                try await client.connect(
                    endpoint: endpoint,
                    token: session.token,
                    audioSessionPreActivated: true
                )
                self.phase = .live
                self.connectedAt = Date()
                self.haptic(.success)
                box.provider.reportOutgoingCall(with: uuid, connectedAt: nil)
            } catch {
                logger.error("WebRTC connect failed: \(error.localizedDescription)")
                box.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                self.realtimeClient = nil
                self.currentCallUUID = nil
                self.phase = .error(error.localizedDescription)
                self.visible = false
            }
        }
    }

    nonisolated public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.realtimeClient?.disconnect()
            self.realtimeClient = nil
        }
    }
}
