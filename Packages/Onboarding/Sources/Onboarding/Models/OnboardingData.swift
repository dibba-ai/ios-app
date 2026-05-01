import ApiClient
import Core
import Foundation

public struct OnboardingData: Sendable, Equatable {
    public var goals: Set<GoalOption> = []
    public var occupation: Set<OccupationOption> = []
    public var housing: Set<HousingOption> = []
    public var transport: Set<TransportOption> = []
    public var currency: String?
    public var age: AgeOption?

    public init() {}

    func toUpdateInput() -> UpdateProfileInput {
        UpdateProfileInput(
            goals: goals.map(\.rawValue),
            occupation: occupation.map(\.rawValue),
            housing: housing.map(\.rawValue),
            transport: transport.map(\.rawValue),
            currency: currency,
            age: age?.rawValue
        )
    }
}
