import Foundation

public enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case goals
    case occupation
    case housing
    case transport
    case currency
    case age
    case finish

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .goals: return "What is your dream?"
        case .occupation: return "What is your occupation?"
        case .housing: return "Where do you live?"
        case .transport: return "How do you commute?"
        case .currency: return "What currency do you use daily?"
        case .age: return "How old are you?"
        case .finish: return "All set"
        }
    }

    public var subtitle: String {
        switch self {
        case .goals, .occupation, .housing, .transport:
            return "Select all that apply to you"
        case .currency, .age:
            return "Select one that applies to you"
        case .finish:
            return "Save your progress"
        }
    }

    /// Progress fraction matching web onboarding: questions answered / 6.
    public var progress: Double {
        switch self {
        case .goals: return 0.0
        case .occupation: return 1.0 / 6.0
        case .housing: return 2.0 / 6.0
        case .transport: return 3.0 / 6.0
        case .currency: return 4.0 / 6.0
        case .age: return 5.0 / 6.0
        case .finish: return 1.0
        }
    }

    public var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
