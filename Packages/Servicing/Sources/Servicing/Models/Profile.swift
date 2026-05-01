import Foundation

// MARK: - Profile Achievement

public struct ProfileAchievement: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

// MARK: - Profile Limit

public struct ProfileLimit: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let period: LimitPeriod
    public let currency: String
    public let target: Double
    public let emoji: String

    public init(
        id: String,
        period: LimitPeriod,
        currency: String,
        target: Double,
        emoji: String
    ) {
        self.id = id
        self.period = period
        self.currency = currency
        self.target = target
        self.emoji = emoji
    }
}

// MARK: - Limit Period

public enum LimitPeriod: String, Codable, Sendable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"

    public var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

// MARK: - Subscription Plan

public enum SubscriptionPlan: RawRepresentable, Codable, Sendable, Equatable {
    case free
    case premium
    case pro
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "DIBBA_AI_FREE":
            self = .free
        case "DIBBA_AI_PREMIUM":
            self = .premium
        case "DIBBA_AI_PRO":
            self = .pro
        default:
            // Handle dynamic plan names (e.g., "DIBBA_AI_PREMIUM_1Y_2025_01_LIVE")
            if rawValue.contains("PREMIUM") || rawValue.contains("PRO") {
                self = .unknown(rawValue)
            } else {
                self = .free
            }
        }
    }

    public var rawValue: String {
        switch self {
        case .free: return "DIBBA_AI_FREE"
        case .premium: return "DIBBA_AI_PREMIUM"
        case .pro: return "DIBBA_AI_PRO"
        case .unknown(let value): return value
        }
    }

    public var isPremium: Bool {
        switch self {
        case .free:
            return false
        case .premium, .pro:
            return true
        case .unknown(let value):
            // Unknown plans containing PREMIUM or PRO are considered premium
            return value.contains("PREMIUM") || value.contains("PRO")
        }
    }

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        case .unknown(let value):
            // Extract a readable name from the plan string
            if value.contains("PREMIUM") { return "Premium" }
            if value.contains("PRO") { return "Pro" }
            return "Free"
        }
    }
}

// MARK: - Profile

public struct Profile: Codable, Equatable, Sendable {
    public let goals: [String]
    public let occupation: [String]
    public let housing: [String]
    public let transport: [String]
    public let currency: String?
    public let age: String?
    public let achievements: [ProfileAchievement]
    public let limits: [ProfileLimit]

    // Notification preferences
    public let notifyDailyReport: Bool
    public let notifyWeeklyReport: Bool
    public let notifyMonthlyReport: Bool
    public let notifyAnnualReport: Bool
    public let notifyNewRecommendation: Bool

    // User info
    public let favoriteRealtimeVoice: String?
    public let createdAt: Date
    public let name: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let picture: String?

    // Subscription
    public let plan: SubscriptionPlan
    public let planStartsAt: Date?
    public let planExpiresAt: Date?

    public init(
        goals: [String] = [],
        occupation: [String] = [],
        housing: [String] = [],
        transport: [String] = [],
        currency: String? = nil,
        age: String? = nil,
        achievements: [ProfileAchievement] = [],
        limits: [ProfileLimit] = [],
        notifyDailyReport: Bool = false,
        notifyWeeklyReport: Bool = true,
        notifyMonthlyReport: Bool = true,
        notifyAnnualReport: Bool = true,
        notifyNewRecommendation: Bool = true,
        favoriteRealtimeVoice: String? = nil,
        createdAt: Date = Date(),
        name: String = "",
        email: String = "",
        firstName: String = "",
        lastName: String = "",
        picture: String? = nil,
        plan: SubscriptionPlan = .free,
        planStartsAt: Date? = nil,
        planExpiresAt: Date? = nil
    ) {
        self.goals = goals
        self.occupation = occupation
        self.housing = housing
        self.transport = transport
        self.currency = currency
        self.age = age
        self.achievements = achievements
        self.limits = limits
        self.notifyDailyReport = notifyDailyReport
        self.notifyWeeklyReport = notifyWeeklyReport
        self.notifyMonthlyReport = notifyMonthlyReport
        self.notifyAnnualReport = notifyAnnualReport
        self.notifyNewRecommendation = notifyNewRecommendation
        self.favoriteRealtimeVoice = favoriteRealtimeVoice
        self.createdAt = createdAt
        self.name = name
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.picture = picture
        self.plan = plan
        self.planStartsAt = planStartsAt
        self.planExpiresAt = planExpiresAt
    }

    enum CodingKeys: String, CodingKey {
        case goals, occupation, housing, transport, currency, age
        case achievements, limits
        case notifyDailyReport = "notify_daily_report"
        case notifyWeeklyReport = "notify_weekly_report"
        case notifyMonthlyReport = "notify_monthly_report"
        case notifyAnnualReport = "notify_annual_report"
        case notifyNewRecommendation = "notify_new_recommendation"
        case favoriteRealtimeVoice = "favorite_realtime_voice"
        case createdAt = "created_at"
        case name, email
        case firstName = "first_name"
        case lastName = "last_name"
        case picture, plan, planStartsAt, planExpiresAt
    }
}

// MARK: - Computed Properties

public extension Profile {
    var isPremium: Bool {
        plan.isPremium
    }

    var displayName: String {
        if !name.isEmpty { return name }
        if !firstName.isEmpty || !lastName.isEmpty {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        return email
    }

    /// Same as `displayName` but never falls back to email — returns nil when no
    /// real name is on the profile. Use for cosmetic surfaces like greetings.
    var greetingName: String? {
        if !name.isEmpty { return name }
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? nil : combined
    }

    var pictureURL: URL? {
        guard let picture else { return nil }
        return URL(string: picture)
    }

    /// True when all 6 onboarding answers are present (matches web onboarding completion).
    var isOnboardingComplete: Bool {
        !goals.isEmpty
            && !occupation.isEmpty
            && !housing.isEmpty
            && !transport.isEmpty
            && currency != nil
            && age != nil
    }
}

// MARK: - Factory (for testing/previews)

public extension Profile {
    static func makeProfile(
        name: String = "Test User",
        email: String = "test@example.com",
        currency: String = "USD",
        plan: SubscriptionPlan = .free
    ) -> Profile {
        Profile(
            currency: currency,
            createdAt: Date(),
            name: name,
            email: email,
            firstName: "Test",
            lastName: "User",
            plan: plan
        )
    }
}
