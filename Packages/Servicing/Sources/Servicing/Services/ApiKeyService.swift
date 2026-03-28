import Foundation
import Dependencies
import Sharing
import ApiClient

// MARK: - API Key Service Protocol

public protocol ApiKeyServicing: Sendable {
    /// Get all API keys
    func getApiKeys(force: Bool) async throws -> [ApiKey]

    /// Create a new API key
    func createApiKey(name: String) async throws -> ApiKey

    /// Get cached API keys
    var cachedApiKeys: [ApiKey] { get async }

    /// Clear cached data
    func clearCache() async
}

// MARK: - API Key Service Implementation

public actor ApiKeyService: ApiKeyServicing {
    @Dependency(\.apiClient) private var client

    // In-memory cache for API keys
    @Shared(.inMemory("cachedApiKeys")) private var _cachedApiKeys: [ApiKey]?

    // Task deduplication
    private var getApiKeysTask: Task<[ApiKey], any Error>?

    public init() {}

    // MARK: - Public Methods

    public var cachedApiKeys: [ApiKey] {
        _cachedApiKeys ?? []
    }

    @discardableResult
    public func getApiKeys(force: Bool = false) async throws -> [ApiKey] {
        // Return in-flight request if exists
        if let getApiKeysTask {
            return try await getApiKeysTask.value
        }

        // Return cache if not forcing refresh
        if let cached = _cachedApiKeys, !cached.isEmpty, !force {
            return cached
        }

        let task = Task<[ApiKey], any Error> {
            let dtos = try await client.listApiKeys()
            return dtos.map { ApiKey(from: $0) }
        }

        getApiKeysTask = task
        defer { getApiKeysTask = nil }

        let apiKeys = try await task.value
        $_cachedApiKeys.withLock { $0 = apiKeys }
        return apiKeys
    }

    public func createApiKey(name: String = "Phone") async throws -> ApiKey {
        let input = CreateApiKeyInput(name: name)
        let dto = try await client.createApiKey(input: input)
        let apiKey = ApiKey(from: dto)

        // Add to cache
        $_cachedApiKeys.withLock { cached in
            var keys = cached ?? []
            keys.insert(apiKey, at: 0)
            cached = keys
        }

        return apiKey
    }

    public func clearCache() {
        $_cachedApiKeys.withLock { $0 = nil }
        getApiKeysTask?.cancel()
        getApiKeysTask = nil
    }
}

// MARK: - ApiKey Conversion

extension ApiKey {
    init(from dto: ApiKeyDTO) {
        let createdAt: Date
        if let isoString = dto.createdAtIso {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: isoString) ?? Date()
        } else if let timestamp = dto.createdAt {
            createdAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            createdAt = Date()
        }

        self.init(
            id: dto.id,
            name: dto.name,
            active: dto.active ?? true,
            createdAt: createdAt,
            createdAtTimestamp: dto.createdAt
        )
    }
}

// MARK: - Dependency Registration

extension ApiKeyService: DependencyKey {
    public static let liveValue: any ApiKeyServicing = ApiKeyService()
    public static let testValue: any ApiKeyServicing = ApiKeyService()
}

public extension DependencyValues {
    var apiKeyService: any ApiKeyServicing {
        get { self[ApiKeyService.self] }
        set { self[ApiKeyService.self] = newValue }
    }
}
