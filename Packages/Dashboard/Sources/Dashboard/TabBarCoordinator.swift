import Auth
import Debug
import Dependencies
import Feed
import FloatingMic
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

        let dashboardNav = makeNavController(
            root: DashboardView().wrapped(),
            title: "Today",
            systemImage: "sun.max.fill"
        )
        let feedNav = makeNavController(
            root: FeedView().wrapped(),
            title: "Feed",
            systemImage: "magnifyingglass"
        )
        let profileNav = makeNavController(
            root: ProfileView(onLogout: onLogout).wrapped(),
            title: "Profile",
            systemImage: "person.fill"
        )
        self.profileNav = profileNav

        let feedTab = UITab(
            title: "Feed",
            image: UIImage(systemName: "magnifyingglass"),
            identifier: Self.feedTabIdentifier
        ) { _ in feedNav }
        let dashboardTab = UITab(
            title: "Today",
            image: UIImage(systemName: "sun.max.fill"),
            identifier: Self.dashboardTabIdentifier
        ) { _ in dashboardNav }
        let profileTab = UITab(
            title: "Profile",
            image: UIImage(systemName: "person.fill"),
            identifier: Self.profileTabIdentifier
        ) { _ in profileNav }

        var tabs: [UITab] = [feedTab, dashboardTab, profileTab]

        if #available(iOS 26.0, *) {
            let micTab = UISearchTab(viewControllerProvider: { _ in UIViewController() })
            micTab.image = UIImage(systemName: "mic.fill")
            micTab.title = ""
            micTab.automaticallyActivatesSearch = false
            tabs.append(micTab)
            micTabIdentifier = micTab.identifier
        }

        tabBarController.tabs = tabs
        tabBarController.selectedTab = dashboardTab
        tabBarController.delegate = self
        logger.info("Tab bar setup complete")
    }

    public func didFinish(coordinator: Coordinating) {
        remove(coordinator)
    }

    @available(iOS 18.0, *)
    public nonisolated func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelectTab tab: UITab
    ) -> Bool {
        let tabIdentifier = tab.identifier
        let didTriggerMic = MainActor.assumeIsolated {
            self.handleTabSelection(tabIdentifier: tabIdentifier)
        }
        return !didTriggerMic
    }

    // MARK: Private

    private let onLogout: (() -> Void)?
    private let micController = FloatingMicController()
    private weak var profileNav: UINavigationController?
    private var profileTapCount = 0
    private var profileLastTapAt: Date = .distantPast
    private var debugFlow: DebugFlow?
    private var micTabIdentifier: String?

    private static let feedTabIdentifier = "ai.dibba.tab.feed"
    private static let dashboardTabIdentifier = "ai.dibba.tab.dashboard"
    private static let profileTabIdentifier = "ai.dibba.tab.profile"

    /// Returns `true` if the tap was consumed by the mic tab (and the tab bar
    /// should not switch).
    private func handleTabSelection(tabIdentifier: String) -> Bool {
        if tabIdentifier == micTabIdentifier {
            micController.tap()
            return true
        }
        if tabIdentifier == Self.profileTabIdentifier {
            handleProfileTap()
        } else {
            profileTapCount = 0
        }
        return false
    }

    private func handleProfileTap() {
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
