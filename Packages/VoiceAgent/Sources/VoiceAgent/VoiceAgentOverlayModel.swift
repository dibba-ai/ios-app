import AVFoundation
import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgent.Overlay")

/// Lightweight record + playback model that backs the overlay.
///
/// Phases:
/// - `idle` — overlay hidden.
/// - `requestingPermission` — waiting for the mic permission prompt.
/// - `recording` — actively capturing audio to `audioURL`.
/// - `recorded` — recording finished, file ready for playback.
/// - `error` — non-fatal failure surfaced to UI.
@MainActor
@Observable
public final class VoiceAgentOverlayModel: NSObject {
    public enum Phase: Sendable, Equatable {
        case idle
        case requestingPermission
        case recording(URL)
        case recorded(URL)
        case error(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var visible: Bool = false
    public private(set) var isPlaying: Bool = false

    /// 0…1 smoothed audio level for glow. Updated ~30Hz while recording.
    public private(set) var level: Float = 0

    public init(storage: RecordingStorage) {
        self.storage = storage
        super.init()
        try? storage.purgeOlderThan(maxAge: 60 * 60 * 24 * 30, referenceDate: Date())
    }

    /// Single entry point bound to the mic tab tap.
    public func toggle() {
        if visible {
            switch phase {
            case .recording:
                stopRecording()
            case .recorded, .error:
                hide()
            case .idle, .requestingPermission:
                hide()
            }
        } else {
            show()
        }
    }

    public func show() {
        guard !visible else { return }
        visible = true
        Task { await self.beginRecording() }
    }

    public func hide() {
        stopMeteringTimer()
        stopPlayback()
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if case .recording(let url) = phase {
            try? FileManager.default.removeItem(at: url)
        }
        visible = false
        phase = .idle
    }

    public func togglePlayback() {
        guard case .recorded(let url) = phase else { return }
        if isPlaying {
            player?.stop()
            player = nil
            isPlaying = false
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
        } catch {
            logger.error("playback failed: \(error.localizedDescription)")
            phase = .error("Playback failed.")
        }
    }

    public func discard() {
        stopMeteringTimer()
        stopPlayback()
        if case .recorded(let url) = phase {
            try? FileManager.default.removeItem(at: url)
        }
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        visible = false
        phase = .idle
    }

    // MARK: Private

    private let storage: RecordingStorage
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    private func beginRecording() async {
        phase = .requestingPermission
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        guard granted else {
            logger.warning("mic permission denied")
            phase = .error("Microphone permission denied.")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let id = UUID()
            let url = storage.makeAudioURL(for: id).deletingPathExtension().appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw NSError(domain: "VoiceAgent", code: -2, userInfo: [NSLocalizedDescriptionKey: "Recorder failed to start"])
            }
            self.recorder = recorder
            self.currentID = id
            self.startedAt = Date()
            phase = .recording(url)
            logger.info("recording to \(url.lastPathComponent)")
            startMeteringTimer()
        } catch {
            logger.error("recording setup failed: \(error.localizedDescription)")
            phase = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        guard case .recording(let url) = phase, let recorder else { return }
        stopMeteringTimer()
        recorder.stop()
        self.recorder = nil
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let metadata = RecordingMetadata(
            id: currentID ?? UUID(),
            createdAt: startedAt ?? Date(),
            duration: duration,
            transcript: "",
            status: .recorded,
            audioFileName: url.lastPathComponent
        )
        try? storage.save(metadata)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        phase = .recorded(url)
        logger.info("recording stopped — \(duration.rounded(.toNearestOrEven))s")
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private var currentID: UUID?
    private var startedAt: Date?
    private var meteringTimer: Timer?

    private func startMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeteredLevel()
            }
        }
    }

    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        level = 0
    }

    private func updateMeteredLevel() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // averagePower returns dBFS in the range [-160, 0]; convert to a 0…1 linear
        // scale with a noise floor at -50 dB so the glow doesn't react to room hiss.
        let db = recorder.averagePower(forChannel: 0)
        let floor: Float = -50
        let clampedDb = max(floor, min(db, 0))
        let normalized = (clampedDb - floor) / -floor // -50→0, 0→1
        let smoothed = level + (normalized - level) * 0.35
        level = max(0, min(1, smoothed))
    }
}

extension VoiceAgentOverlayModel: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    public nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        logger.info("recorderDidFinishRecording success=\(flag)")
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.player = nil
        }
    }
}
