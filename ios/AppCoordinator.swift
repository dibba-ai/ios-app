import Analytics
import Auth
import Dashboard
import Dependencies
import Navigation
import Onboarding
import os.log
import Servicing
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "AppCoordinator")

// MARK: - Root App Flow

@MainActor
final class AppCoordinator: NavigationFlowCoordinating {
    // MARK: Lifecycle

    init(rootNavigationController: UINavigationController) {
        self.rootNavigationController = rootNavigationController
        logger.info("AppCoordinator initialized")
    }

    convenience init() {
        self.init(rootNavigationController: UINavigationController())
    }

    deinit {
        stateSubscriptionTask?.cancel()
    }

    // MARK: Internal

    weak var delegate: CoordinatorDelegate?
    var child: Coordinating?

    let rootNavigationController: UINavigationController

    @Dependency(\.authService) var authService
    @Dependency(\.accountManager) var accountManager
    @Dependency(\.firstLaunchService) var firstLaunchService
    @Dependency(\.appResetService) var appResetService
    @Dependency(\.appResetServiceRegistrar) var appResetServiceRegistrar
    @Dependency(\.profileService) var profileService
    @Dependency(\.transactionService) var transactionService
    @Dependency(\.targetService) var targetService
    @Dependency(\.paywallService) var paywallService
    @Dependency(\.analytics) var analytics

    func start() {
        logger.info("AppCoordinator.start()")

        // Register services for reset on logout
        appResetServiceRegistrar.registerResetters()

        // Show splash while checking state
        showSplash()

        Task {
            // Configure RevenueCat as early as possible — independent of auth.
            await configurePaywall()

            // Handle first launch (clear stale auth from reinstall)
            await firstLaunchService.handleFirstLaunchIfNeeded()

            // Check current auth status
            await authService.checkAuthenticationStatus()

            // Drive onboarding state from server-side profile presence
            if accountManager.isSignedIn {
                await paywallService.identify(userId: authService.currentUser?.id)
                await identifyCurrentUser()
                await evaluateOnboardingFromProfile()
            }

            // Get account state and navigate accordingly
            let state = await accountManager.state
            logger.info("Initial account state: \(String(describing: state))")

            navigateToState(state)
        }
    }

    // MARK: Private

    private var stateSubscriptionTask: Task<Void, Never>?
    private var currentState: AccountState?

    private func showSplash() {
        // Simple splash view while loading
        let splashView = SplashView()
        rootNavigationController.setViewControllers(
            [splashView.wrapped(hideNavBar: true)],
            animated: false
        )
    }

    private func navigateToState(_ state: AccountState) {
        // Avoid duplicate navigation to the same state
        guard state != currentState else {
            logger.info("Already showing state \(String(describing: state)), skipping navigation")
            return
        }

        logger.info("Navigating to state: \(String(describing: state))")
        currentState = state

        switch state {
        case .needAuthenticationAndOnboarding, .needAuthentication:
            startAuthFlow()
        case .needOnboarding:
            startOnboardingFlow()
        case .userReady:
            startHome()
        }
    }

    private func startAuthFlow() {
        logger.info("startAuthFlow()")

        // Remove existing child
        removeChild()

        let auth = AuthFlow(
            rootNavigationController: rootNavigationController,
            onAuthenticated: { [weak self] in
                logger.info("onAuthenticated callback")
                guard let self else { return }

                Task {
                    await self.paywallService.identify(userId: self.authService.currentUser?.id)
                    await self.identifyCurrentUser()
                    await self.evaluateOnboardingFromProfile()
                    let state = await self.accountManager.state
                    await MainActor.run {
                        self.navigateToState(state)
                    }
                }
            }
        )
        add(child: auth)
        auth.start()
    }

    private func startOnboardingFlow() {
        logger.info("startOnboardingFlow()")

        // Remove existing child
        removeChild()

        let onboarding = OnboardingFlow(
            rootNavigationController: rootNavigationController,
            onFinish: { [weak self] in
                logger.info("onFinish callback from onboarding")
                guard let self else { return }

                // Mark onboarding as complete
                self.accountManager.markOnboardingComplete()

                Task {
                    await self.identifyCurrentUser()
                    let state = await self.accountManager.state
                    await MainActor.run {
                        self.navigateToState(state)
                    }
                }
            }
        )
        add(child: onboarding)
        onboarding.start()
        logger.info("OnboardingFlow started")
    }

    private func startHome() {
        logger.info("startHome()")

        // Remove existing child
        removeChild()

        // Preload profile and transactions so views hit warm cache
        Task {
            async let profilePreload: () = preloadProfile()
            async let transactionsPreload: () = preloadTransactions()
            async let targetsPreload: () = preloadTargets()
            _ = await (profilePreload, transactionsPreload, targetsPreload)
            logger.info("Data preloading complete")
        }

        let tabBarCoordinator = TabBarCoordinator(
            onLogout: { [weak self] in
                self?.handleLogout()
            }
        )
        add(child: tabBarCoordinator)
        tabBarCoordinator.start()
        rootNavigationController.setViewControllers(
            [tabBarCoordinator.tabBarController],
            animated: true
        )
        logger.info("TabBarCoordinator set as root")
    }

    private func preloadProfile() async {
        do {
            _ = try await profileService.getProfile(force: false)
            logger.info("Profile preloaded")
        } catch {
            logger.warning("Profile preload failed: \(error.localizedDescription)")
        }
    }

    /// Inspect the server-side profile to decide whether onboarding is needed.
    /// Marks onboarding complete (or resets it) based on `Profile.isOnboardingComplete`.
    /// On fetch failure, leaves the cached flag unchanged so users without connectivity
    /// keep the previously known state.
    private func evaluateOnboardingFromProfile() async {
        do {
            let profile = try await profileService.getProfile(force: false)
            if profile.isOnboardingComplete {
                logger.info("Profile complete — marking onboarding finished")
                accountManager.markOnboardingComplete()
            } else {
                logger.info("Profile incomplete — routing to onboarding")
                accountManager.resetOnboardingState()
            }
        } catch {
            logger.warning("Profile fetch failed during onboarding eval: \(error.localizedDescription) — keeping cached flag")
        }
    }

    private func preloadTransactions() async {
        do {
            _ = try await transactionService.refreshTransactions(perPage: 100)
            logger.info("Transactions preloaded")
        } catch {
            logger.warning("Transactions preload failed: \(error.localizedDescription)")
        }
    }

    private func preloadTargets() async {
        do {
            _ = try await targetService.getTargets(force: false)
            logger.info("Targets preloaded")
        } catch {
            logger.warning("Targets preload failed: \(error.localizedDescription)")
        }
    }

    private func handleLogout() {
        logger.info("handleLogout()")

        // Reset current state to allow navigation
        currentState = nil

        Task {
            // Sign out from Auth0
            try? await authService.signOut()

            // Reset RevenueCat to anonymous so the next sign-in starts clean.
            await paywallService.logout()

            // Capture sign-out before resetting so the event is attributed to the user.
            analytics.capture(.signedOut)

            // Unlink future analytics events from this user.
            analytics.reset()

            // Reset all app state
            try? await appResetService.resetAllState()

            // Navigate back to auth
            await MainActor.run {
                startAuthFlow()
                currentState = .needAuthenticationAndOnboarding
            }
        }
    }

    private func identifyCurrentUser() async {
        guard let userId = await authService.currentUser?.id else {
            logger.warning("Skipping analytics identify — no current user id")
            return
        }

        var props: [String: AnyAnalyticsValue] = [:]
        if let profile = try? await profileService.getProfile(force: false) {
            if !profile.email.isEmpty { props["email"] = .string(profile.email) }
            let display = profile.displayName
            if !display.isEmpty { props["name"] = .string(display) }
            if !profile.firstName.isEmpty { props["first_name"] = .string(profile.firstName) }
            if !profile.lastName.isEmpty { props["last_name"] = .string(profile.lastName) }
            props["plan"] = .string(profile.plan.rawValue)
            if let currency = profile.currency { props["currency"] = .string(currency) }
        }

        analytics.identify(userId: userId, properties: props.isEmpty ? nil : props)
    }

    private func configurePaywall() async {
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicAPIKey") as? String) ?? ""
        guard !apiKey.isEmpty else {
            logger.warning("RevenueCatPublicAPIKey missing in Info.plist — paywall disabled")
            return
        }
        await paywallService.configure(apiKey: apiKey)
    }
}

// MARK: - SplashView

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("AppLogo", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text("Dibba")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
        }
    }
}
