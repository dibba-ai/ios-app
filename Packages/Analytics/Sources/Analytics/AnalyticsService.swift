import Dependencies
import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "Analytics")

// MARK: - Protocol

public protocol AnalyticsServicing: Sendable {
    func capture(_ event: AnalyticsEvent, properties: [String: AnyAnalyticsValue]?)
    func identify(userId: String, properties: [String: AnyAnalyticsValue]?)
    func reset()
}

public extension AnalyticsServicing {
    func capture(_ event: AnalyticsEvent) {
        capture(event, properties: nil)
    }
}

// MARK: - Property Value

/// Type-erased value for analytics properties so a heterogeneous dictionary can cross
/// `Sendable` boundaries (PostHog-friendly, JSON-serialisable).
public enum AnyAnalyticsValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    public var rawValue: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .bool(let value): return value
        case .stringArray(let value): return value
        }
    }
}

extension AnyAnalyticsValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension AnyAnalyticsValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension AnyAnalyticsValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

// MARK: - Logger-only fallback

/// Default implementation that only writes events to the unified log.
/// Replace via `DependencyValues.analytics` once PostHog (or another provider) is wired.
public struct LoggerAnalyticsService: AnalyticsServicing {
    public init() {}

    public func capture(_ event: AnalyticsEvent, properties: [String: AnyAnalyticsValue]?) {
        if let properties, !properties.isEmpty {
            logger.info("event=\(event.rawValue, privacy: .public) props=\(String(describing: properties), privacy: .public)")
        } else {
            logger.info("event=\(event.rawValue, privacy: .public)")
        }
    }

    public func identify(userId: String, properties: [String: AnyAnalyticsValue]?) {
        logger.info("identify userId=\(userId, privacy: .public) props=\(String(describing: properties ?? [:]), privacy: .public)")
    }

    public func reset() {
        logger.info("analytics reset")
    }
}

// MARK: - Dependency Registration

private enum AnalyticsServiceKey: DependencyKey {
    static let liveValue: any AnalyticsServicing = LoggerAnalyticsService()
    static let testValue: any AnalyticsServicing = LoggerAnalyticsService()
}

public extension DependencyValues {
    var analytics: any AnalyticsServicing {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}
