import Foundation

/// Subset of OpenAI Realtime data-channel events we care about. The full event
/// catalogue is large — we decode just the bits the overlay UI uses. Anything
/// else surfaces as `.unknown` so the stream stays lossless.
public enum RealtimeEvent: Sendable {
    /// Streaming assistant transcript chunk (model speech-to-text mirror).
    case assistantTranscriptDelta(itemId: String, text: String)
    /// Final assistant transcript for an output item.
    case assistantTranscriptCompleted(itemId: String, text: String)
    /// Final user transcript (from input audio).
    case userTranscriptCompleted(itemId: String, text: String)
    /// Server-side error payload.
    case error(message: String)
    /// Catch-all so non-decoded events still propagate.
    case unknown(type: String)

    public init?(json: [String: Any]) {
        guard let type = json["type"] as? String else { return nil }
        switch type {
        case "response.audio_transcript.delta":
            let itemId = (json["item_id"] as? String) ?? ""
            let delta = (json["delta"] as? String) ?? ""
            self = .assistantTranscriptDelta(itemId: itemId, text: delta)
        case "response.audio_transcript.done":
            let itemId = (json["item_id"] as? String) ?? ""
            let transcript = (json["transcript"] as? String) ?? ""
            self = .assistantTranscriptCompleted(itemId: itemId, text: transcript)
        case "conversation.item.input_audio_transcription.completed":
            let itemId = (json["item_id"] as? String) ?? ""
            let transcript = (json["transcript"] as? String) ?? ""
            self = .userTranscriptCompleted(itemId: itemId, text: transcript)
        case "error":
            let err = json["error"] as? [String: Any]
            let message = (err?["message"] as? String) ?? "Realtime error"
            self = .error(message: message)
        default:
            self = .unknown(type: type)
        }
    }
}
