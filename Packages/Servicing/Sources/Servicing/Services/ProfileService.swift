import Foundation
import Dependencies
import Sharing
import ApiClient
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "ProfileService")

// MARK: - Profile Service Protocol

public protocol ProfileServicing: Sendable {
    /// Get the current user profile
    func getProfile(force: Bool) async throws -> Profile

    /// Update the user profile
    func updateProfile(_ input: UpdateProfileInput) async throws -> Profile

    /// Get cached profile (if available)
    var cachedProfile: Profile? { get async }

    /// Clear cached data
    func clearCache() async
}

// MARK: - Profile Service Implementation

public actor ProfileService: ProfileServicing {
    @Dependency(\.apiClient) private var client

    // In-memory cache for sensitive profile data
    @Shared(.inMemory("cachedProfile")) private var _cachedProfile: Profile?

    // Task deduplication
    private var getProfileTask: Task<Profile, any Error>?

    public init() {}

    // MARK: - Public Methods

    public var cachedProfile: Profile? {
        _cachedProfile
    }

    @discardableResult
    public func getProfile(force: Bool = false) async throws -> Profile {
        logger.debug("getProfile called, force: \(force)")

        // Return in-flight request if exists
        if let getProfileTask {
            logger.debug("Returning in-flight request")
            return try await getProfileTask.value
        }

        // Return cache if not forcing refresh
        if let cached = _cachedProfile, !force {
            logger.debug("Returning cached profile: \(cached.displayName)")
            return cached
        }

        logger.info("Fetching profile from API")

        // Create new task
        let task = Task<Profile, any Error> {
            let dto = try await client.getProfile()
            let profile = Profile(from: dto)
            logger.info("Profile fetched successfully: \(profile.displayName), plan: \(profile.plan.rawValue)")
            return profile
        }

        getProfileTask = task
        defer { getProfileTask = nil }

        do {
            let profile = try await task.value
            $_cachedProfile.withLock { $0 = profile }
            logger.info("Profile cached successfully")
            return profile
        } catch {
            logger.error("Failed to fetch profile: \(error.localizedDescription)")
            throw error
        }
    }

    public func updateProfile(_ input: UpdateProfileInput) async throws -> Profile {
        let dto = try await client.updateProfile(input: input)
        let profile = Profile(from: dto)
        $_cachedProfile.withLock { $0 = profile }
        return profile
    }

    public func clearCache() {
        $_cachedProfile.withLock { $0 = nil }
        getProfileTask?.cancel()
        getProfileTask = nil
    }
}

// MARK: - Profile Conversion

extension Profile {
    init(from dto: ProfileDTO) {
        self.init(
            goals: dto.goals ?? [],
            occupation: dto.occupation ?? [],
            housing: dto.housing ?? [],
            transport: dto.transport ?? [],
            currency: dto.currency,
            age: dto.age,
            achievements: dto.achievements?.map { ProfileAchievement(from: $0) } ?? [],
            limits: [],
            notifyDailyReport: dto.notifyDailyReport ?? false,
            notifyWeeklyReport: dto.notifyWeeklyReport ?? true,
            notifyMonthlyReport: dto.notifyMonthlyReport ?? true,
            notifyAnnualReport: dto.notifyAnnualReport ?? true,
            notifyNewRecommendation: dto.notifyNewRecommendation ?? true,
            favoriteRealtimeVoice: dto.favoriteRealtimeVoice,
            favoriteVibe: dto.favoriteVibe,
            createdAt: dto.createdAt ?? Date(),
            name: dto.name ?? "",
            email: dto.email ?? "",
            firstName: dto.firstName ?? "",
            lastName: dto.lastName ?? "",
            picture: dto.picture,
            plan: SubscriptionPlan(rawValue: dto.plan ?? "DIBBA_AI_FREE"),
            planStartsAt: dto.planStartsAt,
            planExpiresAt: dto.planExpiresAt
        )
    }
}

extension ProfileAchievement {
    init(from dto: ProfileAchievementDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            createdAt: dto.createdAt ?? Date()
        )
    }
}

// MARK: - Dependency Registration

extension ProfileService: DependencyKey {
    public static let liveValue: any ProfileServicing = ProfileService()
    public static let testValue: any ProfileServicing = ProfileService()
}

public extension DependencyValues {
    var profileService: any ProfileServicing {
        get { self[ProfileService.self] }
        set { self[ProfileService.self] = newValue }
    }
}
