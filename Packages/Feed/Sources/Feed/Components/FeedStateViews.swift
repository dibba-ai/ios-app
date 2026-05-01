import SwiftUI

struct FeedLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct FeedErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: onRetry)
        }
    }
}

struct FeedEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray")
        } description: {
            Text("Your transactions will appear here")
        }
    }
}

struct FeedNoResultsView: View {
    let onClear: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search or filter")
        } actions: {
            Button("Clear Filters", action: onClear)
        }
    }
}
