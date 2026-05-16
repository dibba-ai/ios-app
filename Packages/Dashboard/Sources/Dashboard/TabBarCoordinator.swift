import ApiClient
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
import VoiceAgent
import VoiceAgentCallKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TabBarCoordinator")

@MainActor
public final class TabBarCoordinator: NSObject, CompositionCoordinating, UITabBarControllerDelegate {
    // MARK: Lifecycle

    public init(onLogout: (() -> Void)? = nil) {
        logger.debug("init")
        self.onLogout = onLogout

        @Dependency(\.apiClient) var apiClient
        let model = VoiceAgentOverlayModel(apiClient: apiClient)
        self.voiceOverlayModel = model
        self.voiceOverlayPresenter = VoiceAgentOverlayPresenter(model: model)
        let callKit = VoiceAgentCallKitController(apiClient: apiClient)
        self.voiceCallKitController = callKit
        self.voiceCallKitPresenter = VoiceAgentCallKitOverlayPresenter(controller: callKit)

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
            storedMicTabIdentifier.set(micTab.identifier)
        }

        tabBarController.tabs = tabs
        tabBarController.selectedTab = dashboardTab
        tabBarController.delegate = self
        scheduleOverlayAttachment()
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
        let micIdentifier = self.storedMicTabIdentifier.value
        if let micIdentifier, tabIdentifier == micIdentifier {
            Task { @MainActor in
                switch VoiceAgentModePreference.current {
                case .overlay:
                    self.voiceOverlayModel.toggle()
                case .callKit:
                    self.voiceCallKitController.toggle()
                }
            }
            return false
        }
        Task { @MainActor in
            self.handleNonMicTabSelection(tabIdentifier: tabIdentifier)
        }
        return true
    }

    // MARK: Private

    private let onLogout: (() -> Void)?
    private let voiceOverlayModel: VoiceAgentOverlayModel
    private let voiceOverlayPresenter: VoiceAgentOverlayPresenter
    private let voiceCallKitController: VoiceAgentCallKitController
    private let voiceCallKitPresenter: VoiceAgentCallKitOverlayPresenter
    private weak var profileNav: UINavigationController?
    private var profileTapCount = 0
    private var profileLastTapAt: Date = .distantPast
    private var debugFlow: DebugFlow?
    private let storedMicTabIdentifier = AtomicString()

    private static let feedTabIdentifier = "ai.dibba.tab.feed"
    private static let dashboardTabIdentifier = "ai.dibba.tab.dashboard"
    private static let profileTabIdentifier = "ai.dibba.tab.profile"

    private func handleNonMicTabSelection(tabIdentifier: String) {
        if tabIdentifier == Self.profileTabIdentifier {
            handleProfileTap()
        } else {
            profileTapCount = 0
        }
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

    /// Thread-safe string box for reading the mic tab identifier from the
    /// `UITabBarControllerDelegate` callback without main-actor assumptions.
    private final class AtomicString: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: String?

        var value: String? {
            lock.lock(); defer { lock.unlock() }
            return _value
        }

        func set(_ newValue: String?) {
            lock.lock(); defer { lock.unlock() }
            _value = newValue
        }
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

    /// Waits for `tabBarController.view` to be attached to a window scene, then
    /// mounts the voice-capture overlay window above it. Survives tab switches.
    private func scheduleOverlayAttachment() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<200 {
                if let scene = self.tabBarController.view.window?.windowScene {
                    self.voiceOverlayPresenter.attach(to: scene)
                    self.voiceCallKitPresenter.attach(to: scene)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            logger.warning("voice overlay attach timed out — no window scene")
        }
    }
}
