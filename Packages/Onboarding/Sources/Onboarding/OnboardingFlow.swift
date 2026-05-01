import Navigation
import SwiftUI
import UIKit

@MainActor
public final class OnboardingFlow: NavigationFlowCoordinating {
    // MARK: Lifecycle

    public init(
        rootNavigationController: UINavigationController,
        onFinish: @escaping () -> Void
    ) {
        self.rootNavigationController = rootNavigationController
        self.onFinish = onFinish
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
        let host = OnboardingHostView(viewModel: viewModel)
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
}
