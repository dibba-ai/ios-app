import Foundation

/// Snapshot of the user's premium / subscription state, derived from
/// RevenueCat `CustomerInfo`. Use this for gating decisions.
public struct EntitlementStatus: Sendable, Equatable {
    public let isPremium: Bool
    public let activeEntitlementIds: [String]
    public let activeProductIds: [String]
    public let willRenew: Bool
    public let expirationDate: Date?

    public init(
        isPremium: Bool,
        activeEntitlementIds: [String],
        activeProductIds: [String],
        willRenew: Bool,
        expirationDate: Date?
    ) {
        self.isPremium = isPremium
        self.activeEntitlementIds = activeEntitlementIds
        self.activeProductIds = activeProductIds
        self.willRenew = willRenew
        self.expirationDate = expirationDate
    }

    public static let none = EntitlementStatus(
        isPremium: false,
        activeEntitlementIds: [],
        activeProductIds: [],
        willRenew: false,
        expirationDate: nil
    )
}
