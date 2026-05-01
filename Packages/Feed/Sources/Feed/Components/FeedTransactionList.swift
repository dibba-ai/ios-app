import Servicing
import SwiftUI

struct FeedTransactionList: View {
    let transactions: [Servicing.Transaction]
    let groupedTransactions: [TransactionSection]
    let hasMore: Bool
    @Binding var pendingScrollTarget: String?
    @Binding var selectedTransactionIndex: Int
    @Binding var showingTransactionDetail: Bool
    let onLoadNextPage: () -> Void
    let onRefresh: () async -> Void
    let onDeleted: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(groupedTransactions) { section in
                    Section {
                        ForEach(section.transactions) { transaction in
                            Button {
                                if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                                    selectedTransactionIndex = index
                                    showingTransactionDetail = true
                                }
                            } label: {
                                TransactionRow(transaction: transaction)
                                    .onAppear {
                                        if transaction.id == transactions.last?.id {
                                            onLoadNextPage()
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(formatSectionDate(section.date))
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Text("\(section.transactions.count)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
                    .id(section.date)
                }

                if hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await onRefresh()
            }
            .onChange(of: pendingScrollTarget) { _, target in
                guard let target else { return }
                withAnimation { proxy.scrollTo(target, anchor: .top) }
                pendingScrollTarget = nil
            }
            .sheet(isPresented: $showingTransactionDetail) {
                TransactionDetailDrawer(
                    transactions: transactions,
                    currentIndex: $selectedTransactionIndex,
                    onDeleted: onDeleted
                )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}
