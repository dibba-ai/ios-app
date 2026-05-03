import Foundation

// MARK: - Realtime Voice DTO

public struct RealtimeVoiceDTO: Codable, Sendable {
    public let voice: String
    public let provider: String
    public let name: String
    public let emoji: String?
    public let gender: String?
}

// MARK: - Realtime Options DTO

public struct RealtimeOptionsDTO: Codable, Sendable {
    public let voices: [RealtimeVoiceDTO]
}

// MARK: - Realtime Options Response

public struct RealtimeOptionsResponse: Codable, Sendable {
    public let realtimeOptions: RealtimeOptionsDTO
}
