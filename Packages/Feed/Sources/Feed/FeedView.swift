import Analytics
import Database
import Dependencies
import Servicing
import SwiftUI

public struct FeedView: View {
    public init() {}

    @Dependency(\.transactionService) var transactionService
    @Dependency(\.transactionStore) var store
    @Dependency(\.analytics) var analytics

    @Environment(\.scenePhase) private var scenePhase

    // Page state
    @State var transactions: [Servicing.Transaction] = []
    @State var cursor: TransactionCursor? = nil
    @State var hasMore: Bool = true

    // Loading state
    @State var isLoadingFirstPage = false
    @State var isLoadingNextPage = false
    @State var isRefreshing = false
    @State var isInitialFetch = false
    @State var errorMessage: String?

    // Initial fetch progress
    @State var initialFetchPages = 0
    @State var initialFetchRows = 0
    @State var initialFetchStartedAt: Date?
    @State var initialFetchTask: Task<Void, Never>?

    // Search / filter state
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var filterType: Servicing.TransactionType? = nil

    // Detail / sheets / scroll
    @State var pendingScrollTarget: String? = nil
    @State private var selectedTransactionIndex: Int = 0
    @State private var showingTransactionDetail = false
    @State private var showingDateJump = false
    @State private var jumpDate: Date = Date()
    @State private var showingAddPurchase = false

    var currentFilter: TransactionFilter {
        let q = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let types: Set<String>? = filterType.map { [$0.rawValue] }
        return TransactionFilter(
            search: q.isEmpty ? nil : q,
            types: types,
            dateRange: nil
        )
    }

    var groupedTransactions: [TransactionSection] {
        let grouped = Dictionary(grouping: transactions) { $0.fullDate }
        var seen = Set<String>()
        var orderedDates: [String] = []
        for transaction in transactions {
            if seen.insert(transaction.fullDate).inserted {
                orderedDates.append(transaction.fullDate)
            }
        }
        return orderedDates.map { date in
            TransactionSection(date: date, transactions: grouped[date] ?? [])
        }
    }

    public var body: some View {
        Group {
            if (isInitialFetch || isLoadingFirstPage) && transactions.isEmpty {
                FeedLoadingView()
            } else if let error = errorMessage, transactions.isEmpty {
                FeedErrorView(message: error) {
                    Task { await initialLoad() }
                }
            } else if transactions.isEmpty && !currentFilter.isEmpty {
                FeedNoResultsView {
                    filterType = nil
                    searchText = ""
                    debouncedSearchText = ""
                }
            } else if transactions.isEmpty {
                FeedEmptyView()
            } else {
                FeedTransactionList(
                    transactions: transactions,
                    groupedTransactions: groupedTransactions,
                    hasMore: hasMore,
                    pendingScrollTarget: $pendingScrollTarget,
                    selectedTransactionIndex: $selectedTransactionIndex,
                    showingTransactionDetail: $showingTransactionDetail,
                    onLoadNextPage: { Task { await loadNextPage() } },
                    onRefresh: { await refreshNewTransactions() },
                    onDeleted: { id in transactions.removeAll { $0.id == id } }
                )
            }
        }
        .navigationTitle("Feed")
        .safeAreaInset(edge: .top, spacing: 0) {
            if isInitialFetch, let startedAt = initialFetchStartedAt {
                InitialFetchProgressBanner(
                    pages: initialFetchPages,
                    rows: initialFetchRows,
                    startedAt: startedAt
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search transactions")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                FeedToolbarMenu(
                    filterType: $filterType,
                    onShowDateJump: {
                        jumpDate = Date()
                        showingDateJump = true
                    },
                    onScrollToEnd: { Task { await scrollToEnd() } }
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isRefreshing || isLoadingNextPage {
                    ProgressView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddPurchase = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Purchase")
            }
        }
        .sheet(isPresented: $showingDateJump) {
            FeedJumpDateSheet(
                jumpDate: $jumpDate,
                onCancel: { showingDateJump = false },
                onConfirm: {
                    Task { await scrollToDate(jumpDate) }
                    showingDateJump = false
                }
            )
        }
        .sheet(isPresented: $showingAddPurchase) {
            AddPurchaseView { _ in }
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            if newValue.isEmpty {
                debouncedSearchText = ""
                return
            }
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                debouncedSearchText = newValue
            }
        }
        .onChange(of: debouncedSearchText) { _, _ in
            Task { await reloadFirstPage() }
        }
        .onChange(of: filterType) { _, _ in
            Task { await reloadFirstPage() }
        }
        .task {
            analytics.capture(.feedPageOpened)
            await initialLoad()
        }
        .task {
            for await _ in store.observeChanges() {
                await handleStoreChange()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            switch newValue {
            case .background, .inactive:
                initialFetchTask?.cancel()
                initialFetchTask = nil
            case .active:
                if !UserDefaults.standard.bool(forKey: initialSyncCompletedKey),
                   !isInitialFetch {
                    startInitialFetchTask()
                }
            @unknown default:
                break
            }
        }
    }
}
