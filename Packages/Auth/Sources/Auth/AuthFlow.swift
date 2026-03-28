import Dependencies
import Navigation
import os.log
import SwiftUI
import UI
import UIKit

private let logger = Logger(subsystem: "ai.dibba.ios", category: "AuthFlow")

@MainActor
public final class AuthFlow: NavigationFlowCoordinating {
    // MARK: Lifecycle

    public init(
        rootNavigationController: UINavigationController,
        onAuthenticated: @escaping () -> Void
    ) {
        self.rootNavigationController = rootNavigationController
        self.onAuthenticated = onAuthenticated
        logger.info("AuthFlow initialized")
    }

    // MARK: Public

    public weak var delegate: CoordinatorDelegate?
    public var child: Coordinating?
    public let rootNavigationController: UINavigationController

    @Dependency(\.authService) var authService

    public func start() {
        logger.info("AuthFlow.start() - authState: \(String(describing: self.authService.authState))")

        // Check if already authenticated
        if authService.authState == .authenticated {
            logger.info("Already authenticated, skipping to onAuthenticated")
            finish()
            onAuthenticated()
            return
        }

        logger.info("Showing LoginScreen")
        let view = LoginScreen { [weak self] in
            logger.info("LoginScreen onLogin callback triggered - self is \(self == nil ? "nil" : "valid")")
            guard let self else {
                logger.error("AuthFlow self is nil - cannot proceed!")
                return
            }
            logger.info("Calling finish()")
            self.finish()
            logger.info("Calling onAuthenticated()")
            self.onAuthenticated()
            logger.info("onAuthenticated() returned")
        }
        rootNavigationController.setViewControllers(
            [view.wrapped(hideNavBar: true)],
            animated: true
        )
    }

    public func didFinish(coordinator _: Coordinating) {
        removeChild()
    }

    // MARK: Private

    private let onAuthenticated: () -> Void
}

// MARK: - LoginScreen

private struct LoginScreen: View {
    var onLogin: () -> Void

    @Dependency(\.authService) var authService

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Logo
            Image(systemName: "shield.checkered")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Dibba.ai")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Save for your dream with AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Login Button
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(height: 50)
                Text("Signing in...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task {
                        await signIn()
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Sign in")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
                .frame(height: 40)

            Spacer()
                .frame(height: 20)
        }
        .padding(.horizontal, 32)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signIn()

            if authService.authState == .authenticated {
                logger.info("Sign in successful, calling onLogin")
                onLogin()
            } else {
                logger.warning("Sign in completed but not authenticated")
                errorMessage = "Sign in failed. Please try again."
                showingError = true
            }
        } catch {
            logger.error("Sign in error: \(error.localizedDescription)")
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}
