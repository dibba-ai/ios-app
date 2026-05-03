import ApiClient
import Foundation

// MARK: - Realtime Voice

public struct RealtimeVoice: Codable, Equatable, Sendable, Identifiable, Hashable {
    public let voice: String
    public let provider: String
    public let name: String
    public let emoji: String?
    public let gender: String?

    public var id: String { voice }

    public init(
        voice: String,
        provider: String,
        name: String,
        emoji: String? = nil,
        gender: String? = nil
    ) {
        self.voice = voice
        self.provider = provider
        self.name = name
        self.emoji = emoji
        self.gender = gender
    }
}

// MARK: - DTO Conversion

public extension RealtimeVoice {
    init(from dto: RealtimeVoiceDTO) {
        self.init(
            voice: dto.voice,
            provider: dto.provider,
            name: dto.name,
            emoji: dto.emoji,
            gender: dto.gender
        )
    }
}
