import Foundation
import PostHog
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "PostHogAnalytics")

// MARK: - PostHog-backed Analytics Service

public struct PostHogAnalyticsService: AnalyticsServicing {
    public init() {}

    public func capture(_ event: AnalyticsEvent, properties: [String: AnyAnalyticsValue]?) {
        let props = properties?.mapValues { $0.rawValue }
        if let props, !props.isEmpty {
            logger.info("📊 capture event=\(event.rawValue, privacy: .public) props=\(String(describing: props), privacy: .public)")
        } else {
            logger.info("📊 capture event=\(event.rawValue, privacy: .public)")
        }
        PostHogSDK.shared.capture(event.rawValue, properties: props)
    }

    public func identify(userId: String, properties: [String: AnyAnalyticsValue]?) {
        let props = properties?.mapValues { $0.rawValue }
        logger.info("📊 identify userId=\(userId, privacy: .public) props=\(String(describing: props ?? [:]), privacy: .public)")
        PostHogSDK.shared.identify(userId, userProperties: props)
    }

    public func reset() {
        logger.info("📊 reset")
        PostHogSDK.shared.reset()
    }

    public func flush() {
        logger.info("📊 flush")
        PostHogSDK.shared.flush()
    }
}

// MARK: - Setup Entry Point

public enum PostHogAnalytics {
    public static func setup(projectToken: String, host: String = "https://us.i.posthog.com") {
        let config = PostHogConfig(apiKey: projectToken, host: host)
        PostHogSDK.shared.setup(config)
        logger.info("PostHog configured host=\(host, privacy: .public)")
    }
}

// MARK: - Idempotent Bootstrap

/// Reads PostHog credentials from `Info.plist` and configures the SDK exactly once.
/// Safe to call from `AppDelegate.didFinishLaunchingWithOptions` and from App Intent
/// `perform()` entry points (which run in extension contexts where the AppDelegate
/// hook does not fire).
public enum Analytics {
    private static let bootstrapOnce: Void = {
        let bundle = Bundle.main
        let token = (bundle.object(forInfoDictionaryKey: "PostHogProjectToken") as? String) ?? ""
        let host = (bundle.object(forInfoDictionaryKey: "PostHogHost") as? String) ?? ""
        guard !token.isEmpty, !host.isEmpty else {
            logger.warning("PostHogProjectToken or PostHogHost missing in Info.plist — analytics disabled")
            return
        }
        PostHogAnalytics.setup(projectToken: token, host: host)
    }()

    public static func bootstrap() {
        _ = bootstrapOnce
    }
}
