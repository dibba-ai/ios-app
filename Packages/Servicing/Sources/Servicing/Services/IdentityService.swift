import ApiClient
import Auth
import Dependencies
import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "IdentityService")

// MARK: - Identity Service Protocol

public protocol IdentityServicing: Sendable {
    /// Fetch identity record. Returns nil if user has no record yet (404).
    func getIdentity() async throws -> IdentityDTO?

    /// Bootstrap identity. Tries to fetch; if absent, creates one from the
    /// currently-authenticated Auth0 user's name + picture. Safe to call on
    /// every authenticated app start — server treats createCurrentUser as the
    /// one-time provisioning step and subsequent getIdentity returns the
    /// existing record.
    @discardableResult
    func bootstrap() async throws -> IdentityDTO
}

// MARK: - Identity Service Implementation

public actor IdentityService: IdentityServicing {
    @Dependency(\.apiClient) private var client
    @Dependency(\.authService) private var authService

    public init() {}

    public func getIdentity() async throws -> IdentityDTO? {
        try await client.getIdentity()
    }

    @discardableResult
    public func bootstrap() async throws -> IdentityDTO {
        if let existing = try await client.getIdentity() {
            logger.info("Identity already exists: \(existing.id)")
            return existing
        }

        logger.info("No identity record — creating from Auth0 profile")
        let user = await authService.currentUser
        let input = CreateIdentityInput(
            name: user?.name,
            photoUrl: user?.picture?.absoluteString
        )
        let created = try await client.createIdentity(input: input)
        logger.info("Identity created: \(created.id)")
        return created
    }
}

// MARK: - Dependency Registration

extension IdentityService: DependencyKey {
    public static let liveValue: any IdentityServicing = IdentityService()
    public static let testValue: any IdentityServicing = IdentityService()
}

public extension DependencyValues {
    var identityService: any IdentityServicing {
        get { self[IdentityService.self] }
        set { self[IdentityService.self] = newValue }
    }
}
