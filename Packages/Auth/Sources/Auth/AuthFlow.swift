import AuthenticationServices
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
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: 60)

            Image("AppLogo", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text("Dibba")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Save for your dream with AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(height: 50)
                Text("Signing in...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            Task { await handleAppleResult(result) }
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        Task { await signInWebAuth() }
                    } label: {
                        Text("Other sign in methods")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            LegalFooter()
                .padding(.top, 16)
                .padding(.bottom, 8)
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

    private func signInWebAuth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signIn()
            if authService.authState == .authenticated {
                logger.info("WebAuth sign in successful, calling onLogin")
                onLogin()
            } else {
                logger.warning("WebAuth sign in completed but not authenticated")
                errorMessage = "Sign in failed. Please try again."
                showingError = true
            }
        } catch {
            logger.error("WebAuth sign in error: \(error.localizedDescription)")
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let authCodeData = credential.authorizationCode,
                  let authCode = String(data: authCodeData, encoding: .utf8)
            else {
                logger.error("Apple authorization missing authorizationCode")
                errorMessage = "Apple sign in failed: missing authorization code"
                showingError = true
                return
            }

            do {
                try await authService.signInWithApple(
                    authorizationCode: authCode,
                    fullName: credential.fullName
                )
                if authService.authState == .authenticated {
                    logger.info("Apple sign in successful, calling onLogin")
                    onLogin()
                } else {
                    logger.warning("Apple sign in completed but not authenticated")
                    errorMessage = "Sign in failed. Please try again."
                    showingError = true
                }
            } catch {
                logger.error("Apple sign in error: \(error.localizedDescription)")
                errorMessage = "Apple sign in failed: \(error.localizedDescription)"
                showingError = true
            }

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                logger.info("Apple sign in cancelled by user")
                return
            }
            logger.error("Apple authorization failed: \(error.localizedDescription)")
            errorMessage = "Apple sign in failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}
