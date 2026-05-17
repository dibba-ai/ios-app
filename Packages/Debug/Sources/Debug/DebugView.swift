import ApiClient
import Auth
import Dependencies
import Foundation
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "DebugView")

struct DebugView: View {
    let onRequestLogout: () -> Void
    let onClose: () -> Void

    @Dependency(\.authService) private var authService
    @Dependency(\.profileService) private var profileService
    @Dependency(\.identityService) private var identityService
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.targetService) private var targetService
    @Dependency(\.reportService) private var reportService
    @Dependency(\.apiKeyService) private var apiKeyService
    @Dependency(\.accountManager) private var accountManager

    @State private var profile: Servicing.Profile?
    @State private var authUser: AuthUser?
    @State private var accessToken: String?
    @State private var identity: IdentityDTO?
    @State private var profileJSONExpanded = false
    @State private var identityJSONExpanded = false
    @State private var copiedLabel: String?
    @State private var showCacheResetConfirmation = false
    @State private var showCacheResetSuccess = false
    @State private var showOnboardingResetConfirmation = false
    @State private var isResettingOnboarding = false

    var body: some View {
        List {
            Section("User") {
                copyRow("ID", value: authUser?.id ?? "—")
                copyRow("JWT", value: accessToken ?? "—")
                copyRow("Email", value: authUser?.email ?? profile?.email ?? "—")
                copyRow("Name", value: authUser?.name ?? profile?.name ?? "—")
            }

            Section("Plan") {
                copyRow("Plan", value: planLabel)
                copyRow("Starts At", value: formatDate(profile?.planStartsAt))
                copyRow("Expires At", value: formatDate(profile?.planExpiresAt))
            }

            Section("Identity") {
                copyRow("ID", value: identity?.id ?? "—")
                copyRow("Name", value: identity?.name ?? "—")
                copyRow("Photo URL", value: identity?.photoUrl ?? "—")
                copyRow("Platform", value: identity?.platform ?? "—")
                copyRow("Created At", value: formatDate(identity?.createdAt))
                copyRow("Last Login", value: formatDate(identity?.lastLogin))
            }

            Section("Profile JSON") {
                DisclosureGroup("Show full profile", isExpanded: $profileJSONExpanded) {
                    Button {
                        copy(profileJSON, label: "Profile JSON")
                    } label: {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(profileJSON)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(.vertical, 4)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Identity JSON") {
                DisclosureGroup("Show full identity", isExpanded: $identityJSONExpanded) {
                    Button {
                        copy(identityJSON, label: "Identity JSON")
                    } label: {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(identityJSON)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(.vertical, 4)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Cache") {
                Button {
                    showCacheResetConfirmation = true
                } label: {
                    Label("Reset Cache", systemImage: "arrow.triangle.2.circlepath")
                }
                .alert("Reset Cache", isPresented: $showCacheResetConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        Task {
                            await transactionService.clearCache()
                            await targetService.clearCache()
                            await reportService.clearCache()
                            await profileService.clearCache()
                            await apiKeyService.clearCache()
                            showCacheResetSuccess = true
                        }
                    }
                } message: {
                    Text("This will clear all cached data. The app will re-download as you browse. For a clean re-sync, force-quit and reopen the app.")
                }
                .alert("Cache Cleared", isPresented: $showCacheResetSuccess) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("All cached data has been cleared. Force-quit and reopen the app to re-download from scratch.")
                }
            }

            Section("Onboarding") {
                Button {
                    showOnboardingResetConfirmation = true
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.uturn.backward.circle")
                        .foregroundStyle(.red)
                }
                .disabled(isResettingOnboarding)
                .alert("Reset Onboarding", isPresented: $showOnboardingResetConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset & Sign Out", role: .destructive) {
                        Task { await resetOnboarding() }
                    }
                } message: {
                    Text("Wipes profile preferences (goals, occupation, housing, transport, currency, age) on the server, clears local cache, and signs you out. Sign back in to re-run onboarding.")
                }
            }

            Section {
                Button(role: .cancel) {
                    onClose()
                } label: {
                    Label("Exit Debug", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let copiedLabel {
                Text("Copied: \(copiedLabel)")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData(force: true)
        }
    }

    @ViewBuilder
    private func copyRow(_ label: String, value: String) -> some View {
        Button {
            copy(value, label: label)
        } label: {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func copy(_ value: String, label: String) {
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.2)) {
            copiedLabel = label
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                copiedLabel = nil
            }
        }
    }

    private var planLabel: String {
        guard let plan = profile?.plan else { return "—" }
        return "\(plan.displayName) (\(plan.rawValue))"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.iso8601)
    }

    private var profileJSON: String {
        guard let profile else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profile),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    private var identityJSON: String {
        guard let identity else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(identity),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    private func loadData(force: Bool = false) async {
        do {
            profile = try await profileService.getProfile(force: force)
        } catch {
            logger.error("DebugView profile load failed: \(error.localizedDescription)")
        }
        authUser = await authService.currentUser
        do {
            accessToken = try await authService.accessToken()
        } catch {
            logger.error("DebugView access token load failed: \(error.localizedDescription)")
            accessToken = nil
        }
        do {
            identity = try await identityService.getIdentity()
        } catch {
            logger.error("DebugView identity load failed: \(error.localizedDescription)")
            identity = nil
        }
    }

    @MainActor
    private func resetOnboarding() async {
        guard !isResettingOnboarding else { return }
        isResettingOnboarding = true
        defer { isResettingOnboarding = false }

        let clearInput = UpdateProfileInput(
            goals: [],
            occupation: [],
            housing: [],
            transport: [],
            currency: nil,
            age: nil
        )
        do {
            _ = try await profileService.updateProfile(clearInput)
        } catch {
            logger.error("Reset onboarding: server clear failed: \(error.localizedDescription)")
        }

        await profileService.clearCache()
        accountManager.resetOnboardingState()

        onRequestLogout()
    }
}
