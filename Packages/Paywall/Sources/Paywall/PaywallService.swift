import Dependencies
import Foundation

public protocol PaywallServicing: Sendable {
    /// Configure the underlying SDK exactly once at app launch.
    /// Subsequent calls are no-ops. Pass the public RevenueCat iOS API key.
    func configure(apiKey: String) async

    /// Identify the user after sign-in (e.g. Auth0 `sub`). Pass nil for anonymous.
    func identify(userId: String?) async

    /// Switch back to anonymous on sign-out. Clears cached customer info.
    func logout() async

    /// Fetch all paywall variations (offerings) configured on the dashboard.
    func fetchVariations() async throws -> [PaywallVariation]

    /// Fetch a specific variation by identifier. Pass `nil` for the dashboard's
    /// "Current" offering.
    func fetchVariation(id: String?) async throws -> PaywallVariation?

    /// Buy a product (`PaywallProduct.id`) inside a variation (`PaywallVariation.id`).
    /// Returns the entitlement status after the purchase settles.
    @discardableResult
    func purchase(productId: String, inVariationId variationId: String) async throws -> EntitlementStatus

    /// Apple-required restore-purchases flow.
    @discardableResult
    func restore() async throws -> EntitlementStatus

    /// Snapshot of the current entitlement state. Pass `force: true` to bypass cache.
    func currentEntitlements(force: Bool) async throws -> EntitlementStatus

    /// Reactive stream of entitlement updates. Backed by `Purchases.customerInfoStream`.
    var entitlementUpdates: AsyncStream<EntitlementStatus> { get }
}

// MARK: - Dependency Registration

private enum PaywallServiceKey: DependencyKey {
    static let liveValue: any PaywallServicing = RevenueCatPaywallService()
    static let testValue: any PaywallServicing = NoopPaywallService()
    static let previewValue: any PaywallServicing = NoopPaywallService()
}

public extension DependencyValues {
    var paywallService: any PaywallServicing {
        get { self[PaywallServiceKey.self] }
        set { self[PaywallServiceKey.self] = newValue }
    }
}
