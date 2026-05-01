import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "DashboardView")

public struct DashboardView: View {
    public init() {
        logger.debug("init")
    }

    public var body: some View {
        let _ = logger.debug("body rendered")
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GreetingView(name: isLoading ? "placeholder" : profile?.greetingName)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .padding(.horizontal)

                TargetsView()

                RecentTransactionsView()
            }
            .padding(.vertical)
        }
        .task {
            await loadProfile()
        }
    }

    // MARK: - Private

    @Dependency(\.profileService) private var profileService
    @State private var profile: Servicing.Profile?
    @State private var isLoading = true

    private func loadProfile() async {
        // Check cache first (populated by AppCoordinator preload)
        if let cached = await profileService.cachedProfile {
            profile = cached
            isLoading = false
            return
        }

        // Fallback: fetch from API if cache is empty
        do {
            profile = try await profileService.getProfile(force: false)
        } catch {
            logger.error("Failed to load profile: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
