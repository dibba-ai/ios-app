import RevenueCat
import RevenueCatUI
import SwiftUI

/// SwiftUI host that loads a specific RevenueCat offering by identifier and
/// renders its dashboard-configured paywall via `RevenueCatUI.PaywallView`.
///
/// Pass `variationId: nil` to render the offering marked "Current" on the
/// dashboard. Pass an explicit id (e.g. `"winter_sale"`) to switch variations.
public struct PaywallContainer: View {
    // MARK: Lifecycle

    public init(
        variationId: String? = nil,
        onPurchaseCompleted: @escaping () -> Void = {},
        onRestoreCompleted: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.variationId = variationId
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onRestoreCompleted = onRestoreCompleted
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let offering {
                RevenueCatUI.PaywallView(offering: offering)
                    .onPurchaseCompleted { _ in onPurchaseCompleted() }
                    .onRestoreCompleted { _ in onRestoreCompleted() }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage ?? "Failed to load paywall.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadOffering() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Close") { onDismiss() }
                        .buttonStyle(.borderless)
                }
                .padding()
            }
        }
        .task {
            await loadOffering()
        }
    }

    // MARK: Private

    private let variationId: String?
    private let onPurchaseCompleted: () -> Void
    private let onRestoreCompleted: () -> Void
    private let onDismiss: () -> Void

    @State private var offering: Offering?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private func loadOffering() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let id = variationId {
                offering = offerings.offering(identifier: id)
                if offering == nil {
                    errorMessage = "Variation '\(id)' not configured on RevenueCat."
                }
            } else {
                offering = offerings.current
                if offering == nil {
                    errorMessage = "No 'Current' offering set on the RevenueCat dashboard."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
