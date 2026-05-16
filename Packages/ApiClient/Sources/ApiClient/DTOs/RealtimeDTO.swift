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

// MARK: - Realtime Session DTO

public struct RealtimeSessionDTO: Codable, Sendable {
    public let id: String
    public let endpoint: String
    public let model: String?
    public let provider: String
    public let token: String
    public let tokenExpiresAt: Date?

    public init(
        id: String,
        endpoint: String,
        model: String?,
        provider: String,
        token: String,
        tokenExpiresAt: Date?
    ) {
        self.id = id
        self.endpoint = endpoint
        self.model = model
        self.provider = provider
        self.token = token
        self.tokenExpiresAt = tokenExpiresAt
    }
}

// MARK: - Create Realtime Session Input

public struct CreateRealtimeSessionInput: Codable, Sendable {
    public let provider: String
    public let voice: String
    public let vibe: String?

    public init(provider: String = "openai", voice: String, vibe: String? = nil) {
        self.provider = provider
        self.voice = voice
        self.vibe = vibe
    }
}

public struct CreateRealtimeSessionVariables: Codable, Sendable {
    public let input: CreateRealtimeSessionInput
    public init(input: CreateRealtimeSessionInput) { self.input = input }
}

public struct CreateRealtimeSessionResponse: Codable, Sendable {
    public let createRealtimeSession: RealtimeSessionDTO?
}
