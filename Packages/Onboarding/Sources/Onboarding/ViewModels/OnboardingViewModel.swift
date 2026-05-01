import Analytics
import ApiClient
import Core
import Dependencies
import Foundation
import Observation
import os.log
import Servicing

private let logger = Logger(subsystem: "ai.dibba.ios", category: "OnboardingViewModel")

@MainActor
@Observable
public final class OnboardingViewModel {
    // MARK: Lifecycle

    public init(onComplete: @escaping @MainActor () -> Void) {
        self.onComplete = onComplete
    }

    // MARK: Public

    public var step: OnboardingStep = .goals
    public var data = OnboardingData()
    public var isSaving: Bool = false
    public var errorMessage: String?

    public var progress: Double { step.progress }

    public var canAdvance: Bool {
        switch step {
        case .goals: return !data.goals.isEmpty
        case .occupation: return !data.occupation.isEmpty
        case .housing: return !data.housing.isEmpty
        case .transport: return !data.transport.isEmpty
        case .currency: return data.currency != nil
        case .age: return data.age != nil
        case .finish: return !isSaving
        }
    }

    public var primaryButtonTitle: String {
        step == .finish ? "Finish" : "Next"
    }

    // MARK: Selection

    public func toggleGoal(_ option: GoalOption) {
        if data.goals.contains(option) { data.goals.remove(option) } else { data.goals.insert(option) }
    }

    public func toggleOccupation(_ option: OccupationOption) {
        if data.occupation.contains(option) { data.occupation.remove(option) } else { data.occupation.insert(option) }
    }

    public func toggleHousing(_ option: HousingOption) {
        if data.housing.contains(option) { data.housing.remove(option) } else { data.housing.insert(option) }
    }

    public func toggleTransport(_ option: TransportOption) {
        if data.transport.contains(option) { data.transport.remove(option) } else { data.transport.insert(option) }
    }

    public func selectCurrency(_ id: String?) {
        data.currency = id
    }

    public func selectAge(_ option: AgeOption) {
        data.age = option
    }

    // MARK: Flow

    public func advance() {
        guard canAdvance, let next = step.next else { return }
        analytics.capture(.onboardingStepCompleted, properties: snapshotProperties())
        step = next
        if step == .finish {
            analytics.capture(.onboardingAllAnswered, properties: snapshotProperties())
        }
    }

    public func submit() async {
        guard !isSaving else { return }
        analytics.capture(.onboardingSignupClicked)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await profileService.updateProfile(data.toUpdateInput())
            analytics.capture(.onboardingSignupCompleted)
            logger.info("Onboarding profile saved")
            onComplete()
        } catch {
            logger.error("Onboarding submit failed: \(error.localizedDescription)")
            analytics.capture(
                .onboardingSignupFailed,
                properties: ["error": .string(String(describing: error))]
            )
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Private

    @ObservationIgnored @Dependency(\.profileService) private var profileService
    @ObservationIgnored @Dependency(\.analytics) private var analytics

    @ObservationIgnored private let onComplete: @MainActor () -> Void

    private func snapshotProperties() -> [String: AnyAnalyticsValue] {
        [
            "goals": .stringArray(data.goals.map(\.rawValue)),
            "occupation": .stringArray(data.occupation.map(\.rawValue)),
            "housing": .stringArray(data.housing.map(\.rawValue)),
            "transport": .stringArray(data.transport.map(\.rawValue)),
            "currency": .string(data.currency ?? ""),
            "age": .string(data.age?.rawValue ?? "")
        ]
    }
}
