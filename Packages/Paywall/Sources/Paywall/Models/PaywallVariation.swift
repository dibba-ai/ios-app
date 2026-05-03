import Foundation

/// Lightweight representation of a RevenueCat offering — a "paywall variation"
/// configured on the dashboard. Carries enough data for non-RC UI surfaces
/// (e.g. analytics, debug views) without exposing the underlying SDK type.
public struct PaywallVariation: Sendable, Identifiable, Equatable {
    public let id: String                  // Offering identifier (e.g. "default", "winter_sale")
    public let serverDescription: String   // Dashboard description
    public let metadata: [String: String]  // Custom metadata attached on the dashboard
    public let products: [PaywallProduct]

    public init(
        id: String,
        serverDescription: String,
        metadata: [String: String],
        products: [PaywallProduct]
    ) {
        self.id = id
        self.serverDescription = serverDescription
        self.metadata = metadata
        self.products = products
    }
}

/// A purchasable product inside a variation (RevenueCat package).
public struct PaywallProduct: Sendable, Identifiable, Equatable {
    public let id: String                  // Package identifier (e.g. "$rc_monthly")
    public let storeProductId: String      // Underlying StoreKit product id
    public let title: String
    public let priceString: String
    public let periodDescription: String?  // e.g. "month", "year", nil for lifetime

    public init(
        id: String,
        storeProductId: String,
        title: String,
        priceString: String,
        periodDescription: String?
    ) {
        self.id = id
        self.storeProductId = storeProductId
        self.title = title
        self.priceString = priceString
        self.periodDescription = periodDescription
    }
}
