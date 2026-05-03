import Foundation

public enum PaywallError: Error, Sendable {
    case notConfigured
    case offeringNotFound(id: String)
    case packageNotFound(id: String)
    case underlying(any Error & Sendable)
    case purchaseCancelled
    case unknown(String)
}

extension PaywallError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Paywall is not configured. Call configure(apiKey:) before use."
        case .offeringNotFound(let id):
            return "Paywall variation '\(id)' not found on the RevenueCat dashboard."
        case .packageNotFound(let id):
            return "Paywall product '\(id)' not found in the variation."
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .underlying(let error):
            return error.localizedDescription
        case .unknown(let message):
            return message
        }
    }
}
