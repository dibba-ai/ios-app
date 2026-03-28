import Foundation
import Auth

// MARK: - Service StateResetting Extensions
//
// Following Praktika's pattern, services conform to StateResetting via extensions.
// This allows them to be registered with AppResetService for logout cleanup.

extension ProfileService: StateResetting {
    public func resetState() async throws {
        await clearCache()
    }
}

extension TransactionService: StateResetting {
    public func resetState() async throws {
        await clearCache()
    }
}

extension TargetService: StateResetting {
    public func resetState() async throws {
        await clearCache()
    }
}

extension ReportService: StateResetting {
    public func resetState() async throws {
        await clearCache()
    }
}

extension ApiKeyService: StateResetting {
    public func resetState() async throws {
        await clearCache()
    }
}
