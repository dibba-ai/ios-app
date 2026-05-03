import Analytics
import Dependencies
import SwiftUI

/// Drop-in SwiftUI button that opens the paywall in a sheet. Owns its own
/// presentation state so feature modules never have to wire `.sheet` or know
/// anything about RevenueCat.
///
/// Usage:
/// ```swift
/// if !profile.isPremium {
///     UpgradePremiumButton()
/// }
/// ```
public struct UpgradePremiumButton: View {
    // MARK: Lifecycle

    public init(
        label: String = "Upgrade to Premium",
        variationId: String? = nil
    ) {
        self.label = label
        self.variationId = variationId
    }

    // MARK: Public

    @Dependency(\.analytics) private var analytics

    public var body: some View {
        Button {
            analytics.capture(.paywallClicked)
            isPaywallPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text(label)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .sheet(isPresented: $isPaywallPresented) {
            PaywallContainer(
                variationId: variationId,
                onPurchaseCompleted: { isPaywallPresented = false },
                onDismiss: { isPaywallPresented = false }
            )
        }
    }

    // MARK: Private

    private let label: String
    private let variationId: String?

    @State private var isPaywallPresented = false
}
