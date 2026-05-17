import Analytics
import Dependencies
import SwiftUI

/// Drop-in SwiftUI button that opens the paywall in a sheet. Owns its own
/// presentation state so feature modules never have to wire `.sheet` or know
/// anything about RevenueCat.
///
/// `onPremiumActivated` fires after the subscription activation cover finishes
/// — at that point the server-side profile has flipped to premium. Parents
/// (e.g. ProfileView) should refresh their local profile state from inside it.
///
/// Usage:
/// ```swift
/// if !profile.isPremium {
///     UpgradePremiumButton(onPremiumActivated: { await reloadProfile() })
/// }
/// ```
public struct UpgradePremiumButton: View {
    // MARK: Lifecycle

    public init(
        label: String = "Upgrade to Premium",
        variationId: String? = nil,
        onPremiumActivated: (() -> Void)? = nil
    ) {
        self.label = label
        self.variationId = variationId
        self.onPremiumActivated = onPremiumActivated
    }

    // MARK: Public

    @Dependency(\.analytics) private var analytics

    public var body: some View {
        Button {
            analytics.capture(.paywallClicked)
            isPaywallPresented = true
        } label: {
            HStack(spacing: 8) {
                Text("⭐️")
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
        .sheet(isPresented: $isPaywallPresented, onDismiss: {
            // Fires after the sheet has fully dismissed. Safe to present the
            // activation cover here without racing the UIKit modal stack.
            if pendingActivation {
                pendingActivation = false
                isActivating = true
            }
        }) {
            PaywallContainer(
                variationId: variationId,
                onPurchaseCompleted: {
                    pendingActivation = true
                    isPaywallPresented = false
                },
                onRestoreCompleted: {
                    pendingActivation = true
                    isPaywallPresented = false
                },
                onDismiss: { isPaywallPresented = false }
            )
        }
        .fullScreenCover(isPresented: $isActivating) {
            SubscriptionActivationView(
                onSuccess: {
                    isActivating = false
                    onPremiumActivated?()
                },
                onClose: { isActivating = false }
            )
        }
    }

    // MARK: Private

    private let label: String
    private let variationId: String?
    private let onPremiumActivated: (() -> Void)?

    @State private var isPaywallPresented = false
    @State private var isActivating = false
    @State private var pendingActivation = false
}
