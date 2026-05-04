import Analytics
import ApiClient
import Auth
import Core
import Dependencies
import os.log
import Servicing
import SwiftUI
import UI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "ProfileView")

public struct ProfileView: View {
    public init(onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
    }

    public var body: some View {
        List {
            if let profile = profile {
                ProfileSummarySection(profile: profile)
                // SubscriptionSection(profile: profile)
                PreferencesSection(profile: profile, onUpdate: updateProfile)
                AgentSection(profile: profile, onUpdate: updateProfile)
                NotificationsSection(profile: profile, onUpdate: updateProfile)
                ApiKeysSection(
                    apiKeys: apiKeys,
                    isCreatingApiKey: isCreatingApiKey,
                    onSelectApiKey: { newApiKeyId = $0 },
                    onAddDevice: { Task { await addDevice() } }
                )
                ActionsSection(
                    onContactSupport: {
                        SupportMailComposer.openMail(subject: "Support Request", profile: profile, authUser: authUser)
                    },
                    onDeleteAccountConfirmed: {
                        SupportMailComposer.openMail(subject: "Delete My Account", profile: profile, authUser: authUser)
                    },
                    onSignOutConfirmed: { onLogout?() }
                )

                Section {} footer: {
                    LegalFooter(showVersion: true) { link in
                        switch link {
                        case .terms:
                            analytics.capture(.termsPageOpened)
                        case .privacy:
                            analytics.capture(.privacyPolicyPageOpened)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if isLoadingProfile {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .navigationTitle("Profile")
        .background {
            NavigationLink(
                isActive: Binding(
                    get: { newApiKeyId != nil },
                    set: { if !$0 { newApiKeyId = nil } }
                )
            ) {
                if let apiKeyId = newApiKeyId {
                    ConnectDeviceOptionsView(apiKeyId: apiKeyId)
                }
            } label: {
                EmptyView()
            }
        }
        .task {
            analytics.capture(.profilePageOpened)
            await loadData()
        }
        .refreshable {
            await loadData(force: true)
        }
    }

    @Dependency(\.authService) private var authService
    @Dependency(\.accountManager) private var accountManager
    @Dependency(\.profileService) private var profileService
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.targetService) private var targetService
    @Dependency(\.reportService) private var reportService
    @Dependency(\.apiKeyService) private var apiKeyService
    @Dependency(\.analytics) private var analytics

    @State private var profile: Servicing.Profile?
    @State private var authUser: AuthUser?
    @State private var apiKeys: [Servicing.ApiKey] = []
    @State private var isLoadingProfile = false
    @State private var isUpdating = false
    @State private var isCreatingApiKey = false
    @State private var newApiKeyId: String?

    private let onLogout: (() -> Void)?

    private func loadData(force: Bool = false) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await profileService.getProfile(force: force)
        } catch {
            logger.error("Profile loading failed: \(error.localizedDescription)")
        }

        authUser = await authService.currentUser

        do {
            apiKeys = try await apiKeyService.getApiKeys(force: force)
        } catch {
            logger.error("API keys loading failed: \(error.localizedDescription)")
        }
    }

    private func updateProfile(_ input: UpdateProfileInput) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            profile = try await profileService.updateProfile(input)
        } catch {
            logger.error("Profile update failed: \(error.localizedDescription)")
        }
    }

    private func addDevice() async {
        isCreatingApiKey = true
        defer { isCreatingApiKey = false }

        do {
            let deviceName = UIDevice.current.name
            let apiKey = try await apiKeyService.createApiKey(name: deviceName)
            apiKeys = await apiKeyService.cachedApiKeys
            newApiKeyId = apiKey.id
        } catch {
            logger.error("Failed to create API key: \(error.localizedDescription)")
        }
    }
}
