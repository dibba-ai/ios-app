// The Swift Programming Language
// https://docs.swift.org/swift-book

// Re-export the Paywall package so any consumer that already depends on
// Dashboard (notably the ios app target) can access `paywallService`,
// `PaywallFlow`, and `PaywallContainer` without taking a direct SPM dep.
@_exported import Paywall
