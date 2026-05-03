import SwiftUI
import UIKit

/// Presents a paywall as a modal page sheet on top of any UIKit view controller.
/// Dismisses itself on purchase completion or close. Mirrors the `DebugFlow`
/// pattern used elsewhere in the app.
@MainActor
public final class PaywallFlow {
    // MARK: Lifecycle

    public init(
        presenter: UIViewController,
        variationId: String? = nil,
        onPurchaseCompleted: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.presenter = presenter
        self.variationId = variationId
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public func start() {
        let view = PaywallContainer(
            variationId: variationId,
            onPurchaseCompleted: { [weak self] in self?.handlePurchaseCompleted() },
            onDismiss: { [weak self] in self?.close() }
        )
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .pageSheet
        if #available(iOS 16.0, *) {
            host.sheetPresentationController?.detents = [.large()]
        }
        hostController = host
        presenter?.present(host, animated: true)
    }

    // MARK: Private

    private weak var presenter: UIViewController?
    private weak var hostController: UIViewController?
    private let variationId: String?
    private let onPurchaseCompleted: (() -> Void)?
    private let onDismiss: () -> Void

    private func handlePurchaseCompleted() {
        let purchaseHandler = onPurchaseCompleted
        let dismissHandler = onDismiss
        hostController?.dismiss(animated: true) {
            purchaseHandler?()
            dismissHandler()
        }
    }

    private func close() {
        let dismissHandler = onDismiss
        hostController?.dismiss(animated: true) {
            dismissHandler()
        }
    }
}
