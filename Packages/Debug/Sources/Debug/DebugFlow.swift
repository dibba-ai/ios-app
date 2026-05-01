import SwiftUI
import UIKit

@MainActor
public final class DebugFlow {
    // MARK: Lifecycle

    public init(
        presenter: UIViewController,
        onLogout: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.presenter = presenter
        self.onLogout = onLogout
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public func start() {
        let view = DebugView(
            onRequestLogout: { [weak self] in self?.handleLogout() },
            onClose: { [weak self] in self?.close() }
        )
        let host = UIHostingController(rootView: view)
        host.title = "Debug"
        let nav = UINavigationController(rootViewController: host)
        nav.navigationBar.prefersLargeTitles = false
        nav.modalPresentationStyle = .fullScreen
        navController = nav
        presenter?.present(nav, animated: true)
    }

    // MARK: Private

    private weak var presenter: UIViewController?
    private weak var navController: UINavigationController?
    private let onLogout: (() -> Void)?
    private let onDismiss: () -> Void

    private func handleLogout() {
        let logout = onLogout
        let dismiss = onDismiss
        navController?.dismiss(animated: true) {
            logout?()
            dismiss()
        }
    }

    private func close() {
        let dismiss = onDismiss
        navController?.dismiss(animated: true) {
            dismiss()
        }
    }
}
