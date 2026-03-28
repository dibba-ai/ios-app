import Foundation

// MARK: - API Key DTO

public struct ApiKeyDTO: Codable, Sendable {
    public let id: String
    public let name: String
    public let active: Bool?
    public let createdAt: Int?
    public let createdAtIso: String?

    enum CodingKeys: String, CodingKey {
        case id, name, active
        case createdAt = "created_at"
        case createdAtIso = "created_at_iso"
    }
}

// MARK: - List API Keys Response

public struct ListApiKeysResponse: Codable, Sendable {
    public let listApiKeys: [ApiKeyDTO]
}

// MARK: - Create API Key

public struct CreateApiKeyInput: Encodable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct CreateApiKeyVariables: Encodable, Sendable {
    public let input: CreateApiKeyInput

    public init(input: CreateApiKeyInput) {
        self.input = input
    }
}

public struct CreateApiKeyResponse: Codable, Sendable {
    public let createApiKey: ApiKeyDTO
}
