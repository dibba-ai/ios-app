import Auth
import Dependencies
import Feed
import Navigation
import os.log
import Profile
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TabBarCoordinator")

@MainActor
public final class TabBarCoordinator: CompositionCoordinating {
    // MARK: Lifecycle

    public init(onLogout: (() -> Void)? = nil) {
        logger.debug("init")
        self.onLogout = onLogout
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

        tabBarController.viewControllers = [
            feedNav,
            dashboardNav,
            profileNav,
        ]
        tabBarController.selectedIndex = 1
        logger.info("Tab bar setup complete")
    }

    public func didFinish(coordinator: Coordinating) {
        remove(coordinator)
    }

    // MARK: Private

    private let onLogout: (() -> Void)?

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
