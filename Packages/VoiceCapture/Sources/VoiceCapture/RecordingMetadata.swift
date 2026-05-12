import Foundation

public enum RecordingStatus: String, Codable, Sendable {
    case recorded
    case processed
}

/// Metadata for a single voice-capture recording. Audio bytes live in a separate
/// file referenced by `audioFileName`.
public struct RecordingMetadata: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var duration: TimeInterval
    public var transcript: String
    public var status: RecordingStatus
    public var audioFileName: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        transcript: String = "",
        status: RecordingStatus = .recorded,
        audioFileName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.transcript = transcript
        self.status = status
        self.audioFileName = audioFileName
    }
}
