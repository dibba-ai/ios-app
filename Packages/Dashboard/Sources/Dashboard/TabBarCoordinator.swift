import Auth
import Debug
import Dependencies
import Feed
import Navigation
import os.log
import Profile
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TabBarCoordinator")

@MainActor
public final class TabBarCoordinator: NSObject, CompositionCoordinating, UITabBarControllerDelegate {
    // MARK: Lifecycle

    public init(onLogout: (() -> Void)? = nil) {
        logger.debug("init")
        self.onLogout = onLogout
        super.init()
    }

    // MARK: Public

    public weak var delegate: CoordinatorDelegate?
    public var children: [Coordinating] = []
    public let tabBarController = UITabBarController()

    public func start() {
        logger.info("start - Setting up tab bar")

        logger.debug("Creating DashboardView")
        let dashboardNav = makeNavController(
            root: DashboardView().wrapped(),
            title: "Today",
            systemImage: "sun.max.fill"
        )

        logger.debug("Creating FeedView")
        let feedNav = makeNavController(
            root: FeedView().wrapped(),
            title: "Feed",
            systemImage: "magnifyingglass"
        )

        logger.debug("Creating ProfileView")
        let profileNav = makeNavController(
            root: ProfileView(onLogout: onLogout).wrapped(),
            title: "Profile",
            systemImage: "person.fill"
        )
        self.profileNav = profileNav

        tabBarController.viewControllers = [
            feedNav,
            dashboardNav,
            profileNav,
        ]
        tabBarController.selectedIndex = 1
        tabBarController.delegate = self
        logger.info("Tab bar setup complete")
    }

    public func didFinish(coordinator: Coordinating) {
        remove(coordinator)
    }

    public nonisolated func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        Task { @MainActor in
            self.handleProfileTap(viewController: viewController)
        }
        return true
    }

    // MARK: Private

    private let onLogout: (() -> Void)?
    private weak var profileNav: UINavigationController?
    private var profileTapCount = 0
    private var profileLastTapAt: Date = .distantPast
    private var debugFlow: DebugFlow?

    private func handleProfileTap(viewController: UIViewController) {
        guard viewController === profileNav else {
            profileTapCount = 0
            return
        }
        let now = Date()
        if now.timeIntervalSince(profileLastTapAt) > 2 {
            profileTapCount = 1
        } else {
            profileTapCount += 1
        }
        profileLastTapAt = now
        if profileTapCount >= 10 {
            profileTapCount = 0
            presentDebugFlow()
        }
    }

    private func presentDebugFlow() {
        guard debugFlow == nil else { return }
        let flow = DebugFlow(
            presenter: tabBarController,
            onLogout: onLogout,
            onDismiss: { [weak self] in self?.debugFlow = nil }
        )
        debugFlow = flow
        flow.start()
    }

    private func makeNavController(
        root: UIViewController,
        title: String,
        systemImage: String
    ) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            tag: 0
        )
        return nav
    }
}
