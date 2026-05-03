import Analytics
import Dependencies
import Servicing

/// Wrapper around swift-dependencies that avoids the `@Dependency`
/// property-wrapper name collision with `AppIntents.@Dependency`.
/// Intent files import this module without importing `Dependencies` directly.
enum Services {
    static var transaction: any TransactionServicing {
        @Dependency(\.transactionService) var service
        return service
    }

    static var profile: any ProfileServicing {
        @Dependency(\.profileService) var service
        return service
    }

    static var analytics: any AnalyticsServicing {
        @Dependency(\.analytics) var service
        return service
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
