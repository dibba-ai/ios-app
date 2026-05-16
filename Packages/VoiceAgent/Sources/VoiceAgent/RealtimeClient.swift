import AVFoundation
import Foundation
import LiveKitWebRTC
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgent.RealtimeClient")

public enum RealtimeConnectionState: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case failed(String)
    case closed
}

public enum RealtimeClientError: Error {
    case offerCreationFailed
    case localDescriptionFailed
    case sdpExchangeFailed(Int, String)
    case invalidResponse
    case audioTrackUnavailable
}

/// WebRTC client for OpenAI's Realtime API.
///
/// Lifecycle:
/// 1. `connect(endpoint:token:)` — generate SDP offer, POST to OpenAI w/ Bearer token,
///    set remote SDP, open `oai-events` data channel, attach mic input track.
/// 2. Events flow through `events` AsyncStream.
/// 3. `disconnect()` tears down peer connection cleanly.
public struct RealtimeAudioLevels: Sendable, Equatable {
    /// 0…1 — local microphone amplitude (what the user is sending).
    public var input: Float
    /// 0…1 — remote agent voice amplitude (what's coming back).
    public var output: Float

    public init(input: Float = 0, output: Float = 0) {
        self.input = input
        self.output = output
    }

    public var combined: Float { max(input, output) }
}

@MainActor
public final class RealtimeClient: NSObject {
    public let events: AsyncStream<RealtimeEvent>
    public let states: AsyncStream<RealtimeConnectionState>
    public let audioLevels: AsyncStream<RealtimeAudioLevels>

    public override init() {
        let (eventStream, eventCont) = AsyncStream<RealtimeEvent>.makeStream()
        let (stateStream, stateCont) = AsyncStream<RealtimeConnectionState>.makeStream()
        let (levelStream, levelCont) = AsyncStream<RealtimeAudioLevels>.makeStream()
        self.events = eventStream
        self.states = stateStream
        self.audioLevels = levelStream
        self.eventContinuation = eventCont
        self.stateContinuation = stateCont
        self.audioLevelContinuation = levelCont
        super.init()
    }

    public func connect(endpoint: URL, token: String, audioSessionPreActivated: Bool = false) async throws {
        emitState(.connecting)

        // 1. Configure audio session for VoIP-style playback + record.
        // When CallKit owns the audio session, it activates first and we only
        // need to set our category preferences.
        try configureAudioSession(skipActivation: audioSessionPreActivated)

        // 2. Build peer connection with default config + mic track + data channel.
        let pc = try makePeerConnection()
        self.peerConnection = pc

        let audioTrack = try addLocalAudio(to: pc)
        self.audioTrack = audioTrack

        let dataChannel = makeDataChannel(on: pc)
        self.dataChannel = dataChannel

        // 3. Create local offer.
        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let offerBox: SDPBox = try await withCheckedThrowingContinuation { cont in
            pc.offer(for: constraints) { sdp, error in
                if let sdp { cont.resume(returning: SDPBox(sdp: sdp)); return }
                cont.resume(throwing: error ?? RealtimeClientError.offerCreationFailed)
            }
        }
        let offer = offerBox.sdp
        try await setLocalDescription(pc: pc, sdp: offer)

        // 4. POST offer SDP to OpenAI realtime endpoint.
        let answerSDP = try await exchangeSDP(endpoint: endpoint, token: token, offerSDP: offer.sdp)

        // 5. Apply remote description.
        let answer = LKRTCSessionDescription(type: .answer, sdp: answerSDP)
        try await setRemoteDescription(pc: pc, sdp: answer)

        emitState(.connected)
        attachRemoteAudioRenderers()
        startAudioLevelPolling()
        logger.info("realtime peer connection established")
    }

    /// Walks `pc.transceivers` and attaches a single shared renderer to every
    /// remote audio track so we can read inbound PCM levels directly.
    private func attachRemoteAudioRenderers() {
        guard let pc = peerConnection else { return }
        remoteAudioRenderer.onSample = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.applyRemoteLevel(level)
            }
        }
        var attached = 0
        for transceiver in pc.transceivers {
            guard let track = transceiver.receiver.track as? LKRTCAudioTrack else { continue }
            if attachedRemoteTracks.contains(where: { $0 === track }) { continue }
            track.add(remoteAudioRenderer)
            attachedRemoteTracks.append(track)
            attached += 1
        }
        logger.info("attached remote audio renderers: \(attached) (total tracked: \(self.attachedRemoteTracks.count))")
    }

    fileprivate func attachIfAudio(_ track: LKRTCMediaStreamTrack) {
        guard let audio = track as? LKRTCAudioTrack else { return }
        if attachedRemoteTracks.contains(where: { $0 === audio }) { return }
        if remoteAudioRenderer.onSample == nil {
            remoteAudioRenderer.onSample = { [weak self] level in
                Task { @MainActor [weak self] in
                    self?.applyRemoteLevel(level)
                }
            }
        }
        audio.add(remoteAudioRenderer)
        attachedRemoteTracks.append(audio)
        logger.info("attached remote audio renderer via delegate (total: \(self.attachedRemoteTracks.count))")
    }

    private func detachRemoteAudioRenderers() {
        for track in attachedRemoteTracks {
            track.remove(remoteAudioRenderer)
        }
        attachedRemoteTracks.removeAll()
        remoteAudioRenderer.onSample = nil
    }

    private func applyRemoteLevel(_ level: Float) {
        // Asymmetric smoothing: snap up fast on peaks, decay slowly so the glow
        // tracks audio spikes without jittering.
        let attack: Float = 0.7
        let release: Float = 0.15
        let alpha = level > smoothedOutput ? attack : release
        smoothedOutput += (level - smoothedOutput) * alpha
        audioLevelContinuation.yield(
            RealtimeAudioLevels(input: smoothedInput, output: smoothedOutput)
        )
    }

    public func disconnect() {
        detachRemoteAudioRenderers()
        stopAudioLevelPolling()
        dataChannel?.close()
        dataChannel = nil
        audioTrack?.isEnabled = false
        audioTrack = nil
        peerConnection?.close()
        peerConnection = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        emitState(.closed)
    }

    public func setMicMuted(_ muted: Bool) {
        audioTrack?.isEnabled = !muted
    }

    public func setSpeakerEnabled(_ enabled: Bool) {
        let rtcSession = LKRTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }
        try? rtcSession.overrideOutputAudioPort(enabled ? .speaker : .none)
    }

    // MARK: - Private

    private let eventContinuation: AsyncStream<RealtimeEvent>.Continuation
    private let stateContinuation: AsyncStream<RealtimeConnectionState>.Continuation
    private let audioLevelContinuation: AsyncStream<RealtimeAudioLevels>.Continuation
    private var audioLevelTask: Task<Void, Never>?
    private var smoothedInput: Float = 0
    private var smoothedOutput: Float = 0

    private static let factory: LKRTCPeerConnectionFactory = {
        LKRTCInitializeSSL()
        let encoder = LKRTCDefaultVideoEncoderFactory()
        let decoder = LKRTCDefaultVideoDecoderFactory()
        return LKRTCPeerConnectionFactory(encoderFactory: encoder, decoderFactory: decoder)
    }()

    private var peerConnection: LKRTCPeerConnection?
    private var audioTrack: LKRTCAudioTrack?
    private var dataChannel: LKRTCDataChannel?
    private let remoteAudioRenderer = RemoteAudioLevelRenderer()
    private var attachedRemoteTracks: [LKRTCAudioTrack] = []

    private func emitState(_ state: RealtimeConnectionState) {
        stateContinuation.yield(state)
    }

    private func configureAudioSession(skipActivation: Bool = false) throws {
        // Keep WebRTC's default `.voiceChat` mode so its echo cancellation /
        // AGC / mic capture pipeline isn't disturbed (changing mode broke both
        // input metering and remote audio rendering). We only override:
        //   * categoryOptions to add `.defaultToSpeaker` + Bluetooth output
        //     so audio plays through the main speaker (not the earpiece).
        let config = LKRTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.categoryOptions = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        LKRTCAudioSessionConfiguration.setWebRTC(config)

        let rtcSession = LKRTCAudioSession.sharedInstance()
        if skipActivation {
            // CallKit owns the AVAudioSession active state. Touching it via
            // setConfiguration(_:active:) races CallKit and triggers
            // "Session deactivation failed". Leave it alone — the global
            // config we set via setWebRTC(_:) is what RTC will use when it
            // attaches the mic track.
            try? rtcSession.overrideOutputAudioPort(.speaker)
            return
        }
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }
        try rtcSession.setConfiguration(config, active: true)
        try rtcSession.overrideOutputAudioPort(.speaker)
    }

    private func makePeerConnection() throws -> LKRTCPeerConnection {
        let config = LKRTCConfiguration()
        config.iceServers = [LKRTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let pc = Self.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        ) else {
            throw RealtimeClientError.localDescriptionFailed
        }
        return pc
    }

    private func addLocalAudio(to pc: LKRTCPeerConnection) throws -> LKRTCAudioTrack {
        // Aggressive audio processing: WebRTC's mic source supports legacy
        // `goog*` constraint flags that enable AEC/NS/AGC pipelines. Combined
        // with `.voiceChat` mode at the AVAudioSession layer, this gives us the
        // best client-side defence against speaker→mic echo when output is on
        // the loud media speaker.
        let mandatory: [String: String] = [
            "googEchoCancellation": "true",
            "googEchoCancellation2": "true",
            "googAutoGainControl": "true",
            "googAutoGainControl2": "true",
            "googNoiseSuppression": "true",
            "googNoiseSuppression2": "true",
            "googHighpassFilter": "true",
            "googTypingNoiseDetection": "true",
        ]
        let constraints = LKRTCMediaConstraints(mandatoryConstraints: mandatory, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: constraints)
        let track = Self.factory.audioTrack(with: audioSource, trackId: "mic0")
        pc.add(track, streamIds: ["dibba-stream"])
        return track
    }

    private func makeDataChannel(on pc: LKRTCPeerConnection) -> LKRTCDataChannel? {
        let config = LKRTCDataChannelConfiguration()
        config.isOrdered = true
        let channel = pc.dataChannel(forLabel: "oai-events", configuration: config)
        channel?.delegate = self
        return channel
    }

    private func setLocalDescription(pc: LKRTCPeerConnection, sdp: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pc.setLocalDescription(sdp) { error in
                if let error { cont.resume(throwing: error); return }
                cont.resume()
            }
        }
    }

    private func setRemoteDescription(pc: LKRTCPeerConnection, sdp: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(sdp) { error in
                if let error { cont.resume(throwing: error); return }
                cont.resume()
            }
        }
    }

    private func exchangeSDP(endpoint: URL, token: String, offerSDP: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offerSDP.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RealtimeClientError.invalidResponse
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            logger.error("SDP exchange HTTP \(http.statusCode): \(body, privacy: .public)")
            throw RealtimeClientError.sdpExchangeFailed(http.statusCode, body)
        }
        return body
    }

    // MARK: - Audio level polling

    /// Polls `RTCStatisticsReport` 20×/second and emits inbound + outbound
    /// `audioLevel` values (smoothed). WebRTC exposes per-track audio levels
    /// via `media-source` (outbound mic) and `inbound-rtp` (remote audio) stats.
    private func startAudioLevelPolling() {
        audioLevelTask?.cancel()
        audioLevelTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollAudioLevels()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopAudioLevelPolling() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
        smoothedInput = 0
        smoothedOutput = 0
        audioLevelContinuation.yield(RealtimeAudioLevels(input: 0, output: 0))
    }

    private func pollAudioLevels() async {
        guard let pc = peerConnection else { return }
        let reportBox: StatsReportBox = await withCheckedContinuation { (cont: CheckedContinuation<StatsReportBox, Never>) in
            pc.statistics { report in cont.resume(returning: StatsReportBox(report: report)) }
        }
        var rawInput: Float = 0
        var rawOutput: Float = 0
        for (_, stats) in reportBox.report.statistics {
            guard stats.type == "media-source" else { continue }
            let values = stats.values
            guard (values["kind"] as? String) == "audio" else { continue }
            let level = (values["audioLevel"] as? Double).map(Float.init) ?? 0
            rawInput = max(rawInput, level)
        }
        let attack: Float = 0.7
        let release: Float = 0.15
        let alpha = rawInput > smoothedInput ? attack : release
        smoothedInput += (rawInput - smoothedInput) * alpha
        // smoothedOutput is updated by the remote audio renderer; just re-emit
        // the current combined state with the freshly smoothed input.
        audioLevelContinuation.yield(
            RealtimeAudioLevels(input: smoothedInput, output: smoothedOutput)
        )
    }

    fileprivate func handleIncoming(data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        if let event = RealtimeEvent(json: object) {
            eventContinuation.yield(event)
        }
    }
}

// MARK: - WebRTC delegates

private struct SDPBox: @unchecked Sendable {
    let sdp: LKRTCSessionDescription
}

private struct StatsReportBox: @unchecked Sendable {
    let report: LKRTCStatisticsReport
}

private struct AudioTracksBox: @unchecked Sendable {
    let tracks: [LKRTCMediaStreamTrack]
}

/// Computes RMS from each inbound PCM buffer and forwards a normalised level
/// (0…1). WebRTC delivers `render(pcmBuffer:)` on its own audio thread.
private final class RemoteAudioLevelRenderer: NSObject, LKRTCAudioRenderer, @unchecked Sendable {
    var onSample: ((Float) -> Void)?

    func render(pcmBuffer: AVAudioPCMBuffer) {
        let frames = Int(pcmBuffer.frameLength)
        guard frames > 0 else { return }
        var sumSquares: Float = 0

        if let f = pcmBuffer.floatChannelData?[0] {
            for i in 0..<frames {
                let s = f[i]
                sumSquares += s * s
            }
        } else if let i16 = pcmBuffer.int16ChannelData?[0] {
            // WebRTC commonly delivers signed-16-bit PCM. Scale to ±1.0 first.
            let scale: Float = 1.0 / 32768.0
            for i in 0..<frames {
                let s = Float(i16[i]) * scale
                sumSquares += s * s
            }
        } else if let i32 = pcmBuffer.int32ChannelData?[0] {
            let scale: Float = 1.0 / 2_147_483_648.0
            for i in 0..<frames {
                let s = Float(i32[i]) * scale
                sumSquares += s * s
            }
        } else {
            return
        }

        let rms = sqrtf(sumSquares / Float(frames))
        // Saturate so loud speech maxes the glow.
        let normalised = min(rms / 0.4, 1.0)
        onSample?(normalised)
    }
}

extension RealtimeClient: LKRTCPeerConnectionDelegate {
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCSignalingState) {}
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        let box = AudioTracksBox(tracks: stream.audioTracks)
        Task { @MainActor [weak self] in
            for track in box.tracks {
                self?.attachIfAudio(track)
            }
        }
    }
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd rtpReceiver: LKRTCRtpReceiver, streams mediaStreams: [LKRTCMediaStream]) {
        guard let track = rtpReceiver.track else { return }
        let box = AudioTracksBox(tracks: [track])
        Task { @MainActor [weak self] in
            for track in box.tracks {
                self?.attachIfAudio(track)
            }
        }
    }
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    nonisolated public func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        logger.info("ice state: \(newState.rawValue)")
        if newState == .failed || newState == .disconnected {
            Task { @MainActor [weak self] in
                self?.emitState(.failed("ICE \(newState.rawValue)"))
            }
        }
    }
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {}
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {}
}

extension RealtimeClient: LKRTCDataChannelDelegate {
    nonisolated public func dataChannelDidChangeState(_ dataChannel: LKRTCDataChannel) {
        logger.info("data channel state: \(dataChannel.readyState.rawValue)")
    }

    nonisolated public func dataChannel(_ dataChannel: LKRTCDataChannel, didReceiveMessageWith buffer: LKRTCDataBuffer) {
        let data = buffer.data
        Task { @MainActor [weak self] in
            self?.handleIncoming(data: data)
        }
    }
}
