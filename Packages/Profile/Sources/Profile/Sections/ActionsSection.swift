import SwiftUI

struct ActionsSection: View {
    let onContactSupport: () -> Void
    let onDeleteAccountConfirmed: () -> Void
    let onSignOutConfirmed: () -> Void

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false

    var body: some View {
        Section("Actions") {
            Button(action: onContactSupport) {
                Label("Contact Support", systemImage: "envelope")
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
    }
}
