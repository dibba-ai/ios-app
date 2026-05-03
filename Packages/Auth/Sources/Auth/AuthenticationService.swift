import Auth0
import Dependencies
import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "Auth")

// MARK: - Protocol

/// Protocol for authentication service - enables testing and mocking
public protocol AuthServicing: Sendable {
    /// Current authentication state
    var authState: AuthState { get }

    /// Stream of authentication state changes
    var authStateStream: AsyncStream<AuthState> { get }

    /// Current user profile (nil if not authenticated)
    var currentUser: AuthUser? { get async }

    /// Returns a valid access token from the keychain, refreshing if expired.
    /// Bypasses `authState` gating and the userInfo network call — safe to call
    /// from cold-start contexts (e.g. App Intents) where `checkAuthenticationStatus`
    /// may not have completed yet.
    func accessToken() async throws -> String

    /// Sign in with Auth0 WebAuth (fallback / generic)
    func signIn() async throws

    /// Sign in natively with Apple — exchanges Apple authorization code for Auth0 credentials
    func signInWithApple(authorizationCode: String, fullName: PersonNameComponents?) async throws

    /// Sign out and clear session
    func signOut() async throws

    /// Check and refresh authentication status
    func checkAuthenticationStatus() async

    /// Clear stored credentials
    func clearCredentials()
}

// MARK: - Implementation

public final class AuthenticationService: AuthServicing, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {
        self.credentialsManager = CredentialsManager(authentication: Auth0.authentication())

        // Create the auth state stream
        let (stream, continuation) = AsyncStream<AuthState>.makeStream()
        self._authStateStream = stream
        self._continuation = continuation

        logger.info("AuthenticationService initialized")

        // Check initial state
        Task {
            await checkAuthenticationStatus()
        }
    }

    deinit {
        _continuation.finish()
    }

    // MARK: Public

    public private(set) var authState: AuthState = .unauthenticated {
        didSet {
            if oldValue != authState {
                logger.info("AuthState changed: \(String(describing: oldValue)) -> \(String(describing: self.authState))")
                _continuation.yield(authState)
            }
        }
    }

    public var authStateStream: AsyncStream<AuthState> {
        _authStateStream
    }

    public var currentUser: AuthUser? {
        get async {
            guard authState == .authenticated else { return nil }

            do {
                let credentials = try await credentialsManager.credentials()
                let userInfo = try await Auth0
                    .authentication()
                    .userInfo(withAccessToken: credentials.accessToken)
                    .start()
                return AuthUser(from: userInfo, accessToken: credentials.accessToken)
            } catch {
                logger.error("Failed to get current user: \(error.localizedDescription)")
                return nil
            }
        }
    }

    public func accessToken() async throws -> String {
        let credentials = try await credentialsManager.credentials()
        if authState != .authenticated {
            authState = .authenticated
        }
        return credentials.accessToken
    }

    public func checkAuthenticationStatus() async {
        logger.info("Checking authentication status...")

        do {
            let credentials = try await credentialsManager.credentials()
            // We have valid credentials
            authState = .authenticated
            logger.info("Valid credentials found - authenticated")
        } catch {
            logger.info("No valid credentials: \(error.localizedDescription)")
            authState = .unauthenticated
        }
    }

    public func signIn() async throws {
        logger.info("Starting Auth0 sign in...")

        let credentials = try await Auth0
            .webAuth()
            .scope("openid profile email offline_access")
            .audience("https://getlivepass.com")
            .start()

        let stored = credentialsManager.store(credentials: credentials)
        logger.info("Credentials stored: \(stored)")

        authState = .authenticated
        logger.info("Sign in completed successfully")
    }

    public func signInWithApple(authorizationCode: String, fullName: PersonNameComponents?) async throws {
        logger.info("Starting native Apple sign in...")

        let credentials = try await Auth0
            .authentication()
            .login(
                appleAuthorizationCode: authorizationCode,
                fullName: fullName,
                audience: "https://getlivepass.com",
                scope: "openid profile email offline_access"
            )
            .start()

        let stored = credentialsManager.store(credentials: credentials)
        logger.info("Credentials stored: \(stored)")

        authState = .authenticated
        logger.info("Apple sign in completed successfully")
    }

    public func signOut() async throws {
        logger.info("Starting sign out...")

        do {
            try await Auth0.webAuth().clearSession()
        } catch {
            logger.warning("Failed to clear Auth0 session: \(error.localizedDescription)")
            // Continue with local cleanup even if remote fails
        }

        clearCredentials()
        authState = .unauthenticated
        logger.info("Sign out completed")
    }

    public func clearCredentials() {
        _ = credentialsManager.clear()
        logger.info("Credentials cleared")
    }

    // MARK: Private

    private let credentialsManager: CredentialsManager
    private let _authStateStream: AsyncStream<AuthState>
    private let _continuation: AsyncStream<AuthState>.Continuation
}

// MARK: - Dependency Registration

extension AuthenticationService: DependencyKey {
    public static let liveValue: any AuthServicing = AuthenticationService()
}

public extension DependencyValues {
    var authService: any AuthServicing {
        get { self[AuthenticationService.self] }
        set { self[AuthenticationService.self] = newValue }
    }
}
