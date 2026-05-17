import Foundation

// MARK: - Identity Experience DTO

public struct IdentityExperienceDTO: Codable, Sendable {
    public let plan: String?
    public let planStartsAt: Date?
    public let planExpiresAt: Date?
}

// MARK: - Identity Experiences DTO

public struct IdentityExperiencesDTO: Codable, Sendable {
    public let DIBBA_AI: IdentityExperienceDTO?
}

// MARK: - Identity DTO

public struct IdentityDTO: Codable, Sendable {
    public let id: String
    public let name: String?
    public let photoUrl: String?
    public let createdAt: Date?
    public let lastLogin: Date?
    public let platform: String?
    public let experiences: IdentityExperiencesDTO?
}

// MARK: - Responses

public struct CurrentUserResponse: Codable, Sendable {
    public let currentUser: IdentityDTO?
}

public struct CreateCurrentUserResponse: Codable, Sendable {
    public let createCurrentUser: IdentityDTO?
}

// MARK: - Create Input

public struct CreateIdentityInput: Encodable, Sendable {
    public var name: String?
    public var photoUrl: String?

    public init(name: String?, photoUrl: String?) {
        self.name = name
        self.photoUrl = photoUrl
    }
}

public struct CreateCurrentUserVariables: Encodable, Sendable {
    public let changes: CreateIdentityInput

    public init(changes: CreateIdentityInput) {
        self.changes = changes
    }
}
