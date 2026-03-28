import Foundation
import Dependencies
import Auth
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "AppResetServiceRegistrar")

// MARK: - App Reset Service Registrar

/// Registers all Servicing services with AppResetService for logout cleanup.
/// Following Praktika's pattern: centralized registration at app startup.
///
/// Usage in AppCoordinator or App entry point:
/// ```swift
/// @Dependency(\.appResetServiceRegistrar) var registrar
/// registrar.registerResetters()
/// ```
public struct AppResetServiceRegistrar: Sendable {
    @Dependency(\.appResetService) private var appResetService
    @Dependency(\.profileService) private var profileService
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.targetService) private var targetService
    @Dependency(\.reportService) private var reportService
    @Dependency(\.apiKeyService) private var apiKeyService

    public init() {}

    public func registerResetters() {
        logger.info("Registering services for reset...")

        // Register each service that conforms to StateResetting
        if let service = profileService as? any StateResetting {
            appResetService.register(service)
            logger.debug("Registered ProfileService")
        }

        if let service = transactionService as? any StateResetting {
            appResetService.register(service)
            logger.debug("Registered TransactionService")
        }

        if let service = targetService as? any StateResetting {
            appResetService.register(service)
            logger.debug("Registered TargetService")
        }

        if let service = reportService as? any StateResetting {
            appResetService.register(service)
            logger.debug("Registered ReportService")
        }

        if let service = apiKeyService as? any StateResetting {
            appResetService.register(service)
            logger.debug("Registered ApiKeyService")
        }

        logger.info("All services registered for reset")
    }
}

// MARK: - Dependency Registration

extension AppResetServiceRegistrar: DependencyKey {
    public static let liveValue = AppResetServiceRegistrar()
}

public extension DependencyValues {
    var appResetServiceRegistrar: AppResetServiceRegistrar {
        get { self[AppResetServiceRegistrar.self] }
        set { self[AppResetServiceRegistrar.self] = newValue }
    }
}
