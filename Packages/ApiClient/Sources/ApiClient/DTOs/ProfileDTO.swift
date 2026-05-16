import Foundation

// MARK: - Profile DTO

public struct ProfileDTO: Codable, Sendable {
    public let goals: [String]?
    public let occupation: [String]?
    public let housing: [String]?
    public let transport: [String]?
    public let currency: String?
    public let age: String?
    public let notifyDailyReport: Bool?
    public let notifyWeeklyReport: Bool?
    public let notifyMonthlyReport: Bool?
    public let notifyAnnualReport: Bool?
    public let notifyNewRecommendation: Bool?
    public let favoriteRealtimeVoice: String?
    public let favoriteVibe: String?
    public let achievements: [ProfileAchievementDTO]?
    public let createdAt: Date?
    public let email: String?
    public let name: String?
    public let firstName: String?
    public let lastName: String?
    public let picture: String?
    public let timezone: String?
    public let plan: String?
    public let planStartsAt: Date?
    public let planExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case goals, occupation, housing, transport, currency, age
        case notifyDailyReport = "notify_daily_report"
        case notifyWeeklyReport = "notify_weekly_report"
        case notifyMonthlyReport = "notify_monthly_report"
        case notifyAnnualReport = "notify_annual_report"
        case notifyNewRecommendation = "notify_new_recommendation"
        case favoriteRealtimeVoice = "favorite_realtime_voice"
        case favoriteVibe = "favorite_vibe"
        case achievements
        case createdAt = "created_at"
        case email, name
        case firstName = "first_name"
        case lastName = "last_name"
        case picture, timezone, plan, planStartsAt, planExpiresAt
    }
}

// MARK: - Profile Achievement DTO

public struct ProfileAchievementDTO: Codable, Sendable {
    public let id: String
    public let name: String
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

// MARK: - Profile Response

public struct ProfileResponse: Codable, Sendable {
    public let profile: ProfileDTO
}

// MARK: - Update Profile Input

public struct UpdateProfileInput: Encodable, Sendable {
    public var goals: [String]?
    public var occupation: [String]?
    public var housing: [String]?
    public var transport: [String]?
    public var currency: String?
    public var age: String?
    public var notifyDailyReport: Bool?
    public var notifyWeeklyReport: Bool?
    public var notifyMonthlyReport: Bool?
    public var notifyAnnualReport: Bool?
    public var notifyNewRecommendation: Bool?
    public var favoriteRealtimeVoice: String?
    public var favoriteVibe: String?
    public var name: String?
    public var picture: String?
    public var timezone: String?

    public init(
        goals: [String]? = nil,
        occupation: [String]? = nil,
        housing: [String]? = nil,
        transport: [String]? = nil,
        currency: String? = nil,
        age: String? = nil,
        notifyDailyReport: Bool? = nil,
        notifyWeeklyReport: Bool? = nil,
        notifyMonthlyReport: Bool? = nil,
        notifyAnnualReport: Bool? = nil,
        notifyNewRecommendation: Bool? = nil,
        favoriteRealtimeVoice: String? = nil,
        favoriteVibe: String? = nil,
        name: String? = nil,
        picture: String? = nil,
        timezone: String? = nil
    ) {
        self.goals = goals
        self.occupation = occupation
        self.housing = housing
        self.transport = transport
        self.currency = currency
        self.age = age
        self.notifyDailyReport = notifyDailyReport
        self.notifyWeeklyReport = notifyWeeklyReport
        self.notifyMonthlyReport = notifyMonthlyReport
        self.notifyAnnualReport = notifyAnnualReport
        self.notifyNewRecommendation = notifyNewRecommendation
        self.favoriteRealtimeVoice = favoriteRealtimeVoice
        self.favoriteVibe = favoriteVibe
        self.name = name
        self.picture = picture
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case goals, occupation, housing, transport, currency, age
        case notifyDailyReport = "notify_daily_report"
        case notifyWeeklyReport = "notify_weekly_report"
        case notifyMonthlyReport = "notify_monthly_report"
        case notifyAnnualReport = "notify_annual_report"
        case notifyNewRecommendation = "notify_new_recommendation"
        case favoriteRealtimeVoice = "favorite_realtime_voice"
        case favoriteVibe = "favorite_vibe"
        case name, picture, timezone
    }
}

public struct UpdateProfileVariables: Encodable, Sendable {
    public let input: UpdateProfileInput

    public init(input: UpdateProfileInput) {
        self.input = input
    }
}

public struct UpdateProfileResponse: Codable, Sendable {
    public let updateProfile: ProfileDTO
}
