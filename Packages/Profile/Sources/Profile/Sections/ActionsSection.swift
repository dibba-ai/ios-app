import Dependencies
import Paywall
import SwiftUI
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "ActionsSection")

struct ActionsSection: View {
    let isPremium: Bool
    let onContactSupport: () -> Void
    let onDeleteAccountConfirmed: () -> Void
    let onSignOutConfirmed: () -> Void
    var onPremiumActivated: (() -> Void)? = nil

    @Dependency(\.paywallService) private var paywallService

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isRestoring = false
    @State private var isActivating = false
    @State private var restoreErrorMessage: String?
    @State private var showRestoreError = false

    var body: some View {
        Section("Actions") {
            Button(action: onContactSupport) {
                Label("Contact Support", systemImage: "envelope")
            }

            if !isPremium {
                Button {
                    Task { await restoreSubscription() }
                } label: {
                    HStack {
                        Label("Restore Subscription", systemImage: "arrow.clockwise")
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)
            }

            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive, action: onDeleteAccountConfirmed)
            } message: {
                Text("This will send a request to delete your account and all associated data. This action cannot be undone.")
            }

            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive, action: onSignOutConfirmed)
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .fullScreenCover(isPresented: $isActivating) {
            SubscriptionActivationView(
                onSuccess: {
                    isActivating = false
                    onPremiumActivated?()
                },
                onClose: { isActivating = false }
            )
        }
        .alert("Restore Failed", isPresented: $showRestoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreErrorMessage ?? "Could not restore purchases.")
        }
    }

    private func restoreSubscription() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            _ = try await paywallService.restore()
            isActivating = true
        } catch {
            logger.error("restore failed: \(error.localizedDescription)")
            restoreErrorMessage = error.localizedDescription
            showRestoreError = true
        }
    }
}
