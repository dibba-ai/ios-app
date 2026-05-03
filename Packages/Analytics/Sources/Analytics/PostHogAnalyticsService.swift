import Foundation
import PostHog
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "PostHogAnalytics")

// MARK: - PostHog-backed Analytics Service

public struct PostHogAnalyticsService: AnalyticsServicing {
    public init() {}

    public func capture(_ event: AnalyticsEvent, properties: [String: AnyAnalyticsValue]?) {
        let props = properties?.mapValues { $0.rawValue }
        PostHogSDK.shared.capture(event.rawValue, properties: props)
    }

    public func identify(userId: String, properties: [String: AnyAnalyticsValue]?) {
        let props = properties?.mapValues { $0.rawValue }
        PostHogSDK.shared.identify(userId, userProperties: props)
    }

    public func reset() {
        PostHogSDK.shared.reset()
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
