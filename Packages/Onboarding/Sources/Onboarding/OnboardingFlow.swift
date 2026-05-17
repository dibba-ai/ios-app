import Navigation
import SwiftUI
import UIKit

@MainActor
public final class OnboardingFlow: NavigationFlowCoordinating {
    // MARK: Lifecycle

    public init(
        rootNavigationController: UINavigationController,
        onFinish: @escaping () -> Void,
        onLogout: @escaping () -> Void
    ) {
        self.rootNavigationController = rootNavigationController
        self.onFinish = onFinish
        self.onLogout = onLogout
    }

    // MARK: Public

    public weak var delegate: CoordinatorDelegate?
    public var child: Coordinating?
    public let rootNavigationController: UINavigationController

    public func start() {
        let viewModel = OnboardingViewModel { [weak self] in
            guard let self else { return }
            self.finish()
            self.onFinish()
        }
        let host = OnboardingHostView(viewModel: viewModel, onLogout: onLogout)
        rootNavigationController.setViewControllers(
            [host.wrapped(hideNavBar: true)],
            animated: true
        )
    }

    public func didFinish(coordinator _: Coordinating) {
        removeChild()
    }

    // MARK: Private

    private let onFinish: () -> Void
    private let onLogout: () -> Void
}
