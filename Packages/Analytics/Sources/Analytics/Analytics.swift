// MARK: - Analytics Module
//
// Event tracking abstraction. The `AnalyticsServicing` protocol is the call-site
// contract; `LoggerAnalyticsService` is the default no-network implementation.
// Swap in a real provider (PostHog, etc.) by overriding `DependencyValues.analytics`.
