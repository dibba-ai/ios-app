import Foundation

/// No-op implementation used in tests + previews. Returns empty data and
/// reports the user as non-premium.
public struct NoopPaywallService: PaywallServicing {
    public init() {}

    public func configure(apiKey: String) async {}
    public func identify(userId: String?) async {}
    public func logout() async {}

    public func fetchVariations() async throws -> [PaywallVariation] { [] }
    public func fetchVariation(id: String?) async throws -> PaywallVariation? { nil }

    public func purchase(productId: String, inVariationId variationId: String) async throws -> EntitlementStatus {
        .none
    }

    public func restore() async throws -> EntitlementStatus { .none }
    public func currentEntitlements(force: Bool) async throws -> EntitlementStatus { .none }

    public var entitlementUpdates: AsyncStream<EntitlementStatus> {
        AsyncStream { $0.finish() }
    }
}
