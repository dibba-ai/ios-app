import Dependencies
import Feed
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "RecentTransactionsView")

struct RecentTransactionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent ")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if isLoading {
                cardContainer {
                    ForEach(0 ..< 5, id: \.self) { index in
                        if index > 0 { Divider().padding(.leading, 60) }
                        TransactionRow(transaction: .makeTransaction())
                            .redacted(reason: .placeholder)
                            .padding(.vertical, 4)
                    }
                }
            } else if transactions.isEmpty {
                cardContainer {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No transactions yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else {
                cardContainer {
                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                        if index > 0 { Divider().padding(.leading, 60) }
                        Button {
                            if let idx = allTransactions.firstIndex(where: { $0.id == transaction.id }) {
                                selectedIndex = idx
                            }
                            showingDetail = true
                        } label: {
                            TransactionRow(transaction: transaction)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            TransactionDetailDrawer(
                transactions: allTransactions,
                currentIndex: $selectedIndex
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await loadTransactions()
        }
    }

    // MARK: - Card Container

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Private

    @Dependency(\.transactionService) private var transactionService
    @State private var transactions: [Servicing.Transaction] = []
    @State private var allTransactions: [Servicing.Transaction] = []
    @State private var isLoading = true
    @State private var selectedIndex = 0
    @State private var showingDetail = false

    private func loadTransactions() async {
        do {
            let cached = await transactionService.cachedTransactions
            if !cached.isEmpty {
                allTransactions = cached
                transactions = Array(cached.prefix(5))
                isLoading = false
                return
            }
            let result = try await transactionService.fetchPage(nextToken: nil, perPage: 5)
            allTransactions = result.transactions
            transactions = Array(result.transactions.prefix(5))
        } catch {
            logger.error("Failed to load transactions: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
