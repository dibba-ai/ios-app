import Foundation
import os.log
import RevenueCat

private let logger = Logger(subsystem: "ai.dibba.ios", category: "Paywall")

public actor RevenueCatPaywallService: PaywallServicing {
    public init() {}

    // MARK: Configuration

    private var isConfigured = false

    public func configure(apiKey: String) async {
        guard !isConfigured else {
            logger.debug("Already configured, skipping")
            return
        }
        guard !apiKey.isEmpty else {
            logger.warning("Refusing to configure RevenueCat with an empty API key")
            return
        }
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        logger.info("RevenueCat configured")
    }

    public func identify(userId: String?) async {
        guard isConfigured else {
            logger.warning("identify(userId:) called before configure()")
            return
        }
        do {
            if let userId, !userId.isEmpty {
                _ = try await Purchases.shared.logIn(userId)
                logger.info("RevenueCat identified user \(userId, privacy: .private)")
            } else {
                _ = try await Purchases.shared.logOut()
                logger.info("RevenueCat reset to anonymous")
            }
        } catch {
            logger.error("RevenueCat identify failed: \(error.localizedDescription)")
        }
    }

    public func logout() async {
        guard isConfigured else { return }
        do {
            _ = try await Purchases.shared.logOut()
            logger.info("RevenueCat logged out")
        } catch {
            logger.error("RevenueCat logout failed: \(error.localizedDescription)")
        }
    }

    // MARK: Variations

    public func fetchVariations() async throws -> [PaywallVariation] {
        try ensureConfigured()
        let offerings = try await Purchases.shared.offerings()
        return offerings.all.values
            .sorted { $0.identifier < $1.identifier }
            .map { Self.makeVariation(from: $0) }
    }

    public func fetchVariation(id: String?) async throws -> PaywallVariation? {
        try ensureConfigured()
        let offerings = try await Purchases.shared.offerings()
        let offering: Offering? = if let id {
            offerings.offering(identifier: id)
        } else {
            offerings.current
        }
        guard let offering else {
            if let id { throw PaywallError.offeringNotFound(id: id) }
            return nil
        }
        return Self.makeVariation(from: offering)
    }

    // MARK: Purchase

    @discardableResult
    public func purchase(productId: String, inVariationId variationId: String) async throws -> EntitlementStatus {
        try ensureConfigured()
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: variationId) else {
            throw PaywallError.offeringNotFound(id: variationId)
        }
        guard let package = offering.availablePackages.first(where: { $0.identifier == productId }) else {
            throw PaywallError.packageNotFound(id: productId)
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                throw PaywallError.purchaseCancelled
            }
            return Self.makeStatus(from: result.customerInfo)
        } catch let error as PaywallError {
            throw error
        } catch {
            throw PaywallError.underlying(error as! (any Error & Sendable))
        }
    }

    @discardableResult
    public func restore() async throws -> EntitlementStatus {
        try ensureConfigured()
        let info = try await Purchases.shared.restorePurchases()
        return Self.makeStatus(from: info)
    }

    // MARK: Entitlements

    public func currentEntitlements(force: Bool) async throws -> EntitlementStatus {
        try ensureConfigured()
        let info: CustomerInfo
        if force {
            info = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        } else {
            info = try await Purchases.shared.customerInfo()
        }
        return Self.makeStatus(from: info)
    }

    public nonisolated var entitlementUpdates: AsyncStream<EntitlementStatus> {
        AsyncStream { continuation in
            let task = Task {
                for await info in Purchases.shared.customerInfoStream {
                    continuation.yield(Self.makeStatus(from: info))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Helpers

    private func ensureConfigured() throws {
        guard isConfigured else { throw PaywallError.notConfigured }
    }

    private static func makeVariation(from offering: Offering) -> PaywallVariation {
        let products = offering.availablePackages.map { package -> PaywallProduct in
            let storeProduct = package.storeProduct
            return PaywallProduct(
                id: package.identifier,
                storeProductId: storeProduct.productIdentifier,
                title: storeProduct.localizedTitle,
                priceString: storeProduct.localizedPriceString,
                periodDescription: storeProduct.subscriptionPeriod?.unitDescription
            )
        }
        // Metadata is [String: Any] in the SDK; coerce sensible scalars to strings.
        let metadata: [String: String] = offering.metadata.reduce(into: [:]) { acc, pair in
            if let value = pair.value as? CustomStringConvertible {
                acc[pair.key] = String(describing: value)
            }
        }
        return PaywallVariation(
            id: offering.identifier,
            serverDescription: offering.serverDescription,
            metadata: metadata,
            products: products
        )
    }

    private static func makeStatus(from info: CustomerInfo) -> EntitlementStatus {
        let active = info.entitlements.active
        let willRenew = active.values.contains { $0.willRenew }
        let nextExpiration = active.values.compactMap(\.expirationDate).max()
        return EntitlementStatus(
            isPremium: !active.isEmpty,
            activeEntitlementIds: active.keys.sorted(),
            activeProductIds: active.values.map(\.productIdentifier).sorted(),
            willRenew: willRenew,
            expirationDate: nextExpiration
        )
    }
}

// MARK: - SubscriptionPeriod -> human description

private extension SubscriptionPeriod {
    var unitDescription: String? {
        switch unit {
        case .day: return value == 1 ? "day" : "\(value) days"
        case .week: return value == 1 ? "week" : "\(value) weeks"
        case .month: return value == 1 ? "month" : "\(value) months"
        case .year: return value == 1 ? "year" : "\(value) years"
        @unknown default: return nil
        }
    }
}
