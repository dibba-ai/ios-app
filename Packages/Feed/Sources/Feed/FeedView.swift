import Database
import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "FeedView")

private let pageSize = 100
private let initialFetchDelaySeconds: UInt64 = 3
private let initialSyncCompletedKey = InitialSyncDefaults.completedKey
private let initialSyncNextTokenKey = InitialSyncDefaults.nextTokenKey

// MARK: - Transaction Section

private struct TransactionSection: Identifiable {
    let date: String
    let transactions: [Servicing.Transaction]
    var id: String { date }
}

// MARK: - Date Formatting

private let sectionDateParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

private func formatSectionDate(_ dateString: String) -> String {
    guard let date = sectionDateParser.date(from: dateString) else { return dateString }

    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }

    let formatter = DateFormatter()
    formatter.locale = Locale.current
    if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
        formatter.dateFormat = "MMMM d"
    } else {
        formatter.dateFormat = "MMMM d, yyyy"
    }
    return formatter.string(from: date)
}

// MARK: - Feed View

public struct FeedView: View {
    public init() {}

    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.transactionStore) private var store

    @Environment(\.scenePhase) private var scenePhase

    // Page state
    @State private var transactions: [Servicing.Transaction] = []
    @State private var cursor: TransactionCursor? = nil
    @State private var hasMore: Bool = true

    // Loading state
    @State private var isLoadingFirstPage = false
    @State private var isLoadingNextPage = false
    @State private var isRefreshing = false
    @State private var isInitialFetch = false
    @State private var errorMessage: String?

    // Initial fetch progress
    @State private var initialFetchPages = 0
    @State private var initialFetchRows = 0
    @State private var initialFetchStartedAt: Date?
    @State private var initialFetchTask: Task<Void, Never>?

    // Search / filter state
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var filterType: Servicing.TransactionType? = nil

    // Detail / sheets
    @State private var selectedTransactionIndex: Int = 0
    @State private var showingTransactionDetail = false
    @State private var showingDateJump = false
    @State private var jumpDate: Date = Date()
    @State private var pendingScrollTarget: String? = nil
    @State private var showingAddPurchase = false

    private var currentFilter: TransactionFilter {
        let q = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let types: Set<String>? = filterType.map { [$0.rawValue] }
        return TransactionFilter(
            search: q.isEmpty ? nil : q,
            types: types,
            dateRange: nil
        )
    }

    private var groupedTransactions: [TransactionSection] {
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
                loadingView
            } else if let error = errorMessage, transactions.isEmpty {
                errorView(error)
            } else if transactions.isEmpty && !currentFilter.isEmpty {
                noResultsView
            } else if transactions.isEmpty {
                emptyView
            } else {
                transactionList
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
            ToolbarItem(placement: .topBarLeading) { toolbarMenu }
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
        .sheet(isPresented: $showingDateJump) { jumpDateSheet }
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

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarMenu: some View {
        Menu {
            Picker("Type", selection: $filterType) {
                Text("All Types").tag(Servicing.TransactionType?.none)
                ForEach(Servicing.TransactionType.allCases, id: \.self) { type in
                    Text("\(type.emoji) \(type.displayName)").tag(Servicing.TransactionType?.some(type))
                }
            }

            Section("Jump") {
                Button {
                    jumpDate = Date()
                    showingDateJump = true
                } label: {
                    Label("Scroll to Date", systemImage: "calendar")
                }
                Button {
                    Task { await scrollToEnd() }
                } label: {
                    Label("Scroll to End", systemImage: "arrow.down.to.line")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(filterType == nil ? "" : ".fill")")
        }
    }

    @ViewBuilder
    private var jumpDateSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Scroll to Date",
                    selection: $jumpDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Scroll to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDateJump = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        Task { await scrollToDate(jumpDate) }
                        showingDateJump = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Views

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await initialLoad() }
            }
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray")
        } description: {
            Text("Your transactions will appear here")
        }
    }

    @ViewBuilder
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search or filter")
        } actions: {
            Button("Clear Filters") {
                filterType = nil
                searchText = ""
                debouncedSearchText = ""
            }
        }
    }

    @ViewBuilder
    private var transactionList: some View {
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
                                            Task { await loadNextPage() }
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
                await refreshNewTransactions()
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
                    onDeleted: { id in
                        transactions.removeAll { $0.id == id }
                    }
                )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Data Loading

    private func initialLoad() async {
        await reloadFirstPage()

        // Full sync runs once per install (or until it succeeds end-to-end).
        // After that, we only pull new transactions on launch / pull-to-refresh.
        if UserDefaults.standard.bool(forKey: initialSyncCompletedKey) {
            await refreshNewTransactions()
        } else {
            startInitialFetchTask()
        }
    }

    private func startInitialFetchTask() {
        guard initialFetchTask == nil else { return }
        initialFetchTask = Task { @MainActor in
            await fetchAllFromServer()
            initialFetchTask = nil
        }
    }

    private func fetchAllFromServer() async {
        guard !isInitialFetch else { return }
        isInitialFetch = true
        initialFetchPages = 0
        initialFetchRows = 0
        initialFetchStartedAt = Date()
        errorMessage = nil
        defer {
            isInitialFetch = false
            initialFetchStartedAt = nil
        }

        do {
            // Resume from last persisted token if previous session was interrupted.
            var token: String? = UserDefaults.standard.string(forKey: initialSyncNextTokenKey)
            logger.debug("Initial fetch starting, resume token: \(token ?? "nil")")
            repeat {
                try Task.checkCancellation()
                let page = try await transactionService.fetchPage(nextToken: token, perPage: pageSize)
                token = page.nextToken
                initialFetchPages += 1
                initialFetchRows += page.transactions.count
                logger.debug("Initial fetch page \(initialFetchPages), hasMore: \(token != nil)")
                // Persist token so a kill/background can resume here next launch.
                if let token {
                    UserDefaults.standard.set(token, forKey: initialSyncNextTokenKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: initialSyncNextTokenKey)
                }
                if token != nil {
                    try await Task.sleep(nanoseconds: initialFetchDelaySeconds * 1_000_000_000)
                }
            } while token != nil
            // Reached end of feed — mark sync complete so future launches skip full walk.
            UserDefaults.standard.set(true, forKey: initialSyncCompletedKey)
        } catch is CancellationError {
            logger.info("Initial fetch cancelled")
        } catch {
            if transactions.isEmpty {
                errorMessage = error.localizedDescription
            }
            logger.error("Initial fetch failed: \(error.localizedDescription)")
        }
    }

    private func reloadFirstPage() async {
        guard !isLoadingFirstPage else { return }
        isLoadingFirstPage = true
        defer { isLoadingFirstPage = false }

        do {
            let page = try await store.page(filter: currentFilter, limit: pageSize, after: nil)
            transactions = page.records.compactMap { (rec: TransactionRecord) -> Servicing.Transaction? in
                Servicing.Transaction(from: rec)
            }
            cursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            logger.error("reloadFirstPage failed: \(error.localizedDescription)")
        }
    }

    private func loadNextPage() async {
        guard hasMore, !isLoadingNextPage, !isLoadingFirstPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await store.page(filter: currentFilter, limit: pageSize, after: cursor)
            let newRows = page.records.compactMap { (rec: TransactionRecord) -> Servicing.Transaction? in
                Servicing.Transaction(from: rec)
            }
            transactions.append(contentsOf: newRows)
            cursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            logger.error("loadNextPage failed: \(error.localizedDescription)")
        }
    }

    private func refreshNewTransactions() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await transactionService.refreshTransactions(perPage: pageSize)
        } catch {
            logger.error("refresh failed: \(error.localizedDescription)")
        }
    }

    /// Reacts to store writes (insert/update/delete). Prepends new top items and patches in-place edits.
    /// Skips full reload while a paginated tail is being loaded to preserve scroll position.
    private func handleStoreChange() async {
        guard !isLoadingFirstPage, !isLoadingNextPage else { return }

        do {
            let page = try await store.page(filter: currentFilter, limit: pageSize, after: nil)
            let topRows = page.records.compactMap { (rec: TransactionRecord) -> Servicing.Transaction? in
                Servicing.Transaction(from: rec)
            }

            if cursor == nil {
                transactions = topRows
                cursor = page.nextCursor
                hasMore = page.nextCursor != nil
                return
            }

            let existingIds = Set(transactions.map(\.id))
            let prepend = Array(topRows.prefix { !existingIds.contains($0.id) })
            if !prepend.isEmpty {
                transactions.insert(contentsOf: prepend, at: 0)
            }

            let topById = Dictionary(uniqueKeysWithValues: topRows.map { ($0.id, $0) })
            for i in transactions.indices {
                if let updated = topById[transactions[i].id] {
                    transactions[i] = updated
                }
            }
        } catch {
            logger.error("handleStoreChange failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Jump Logic

    /// Loads pages until a section matching `date` becomes available, then scrolls to it.
    private func scrollToDate(_ date: Date) async {
        let cal = Calendar.current
        let targetTimestamp = Int64(cal.startOfDay(for: date).timeIntervalSince1970)

        // Already loaded?
        if let target = matchingSectionId(for: date) {
            pendingScrollTarget = target
            return
        }

        // Paginate until we pass the target date or run out.
        while hasMore {
            await loadNextPage()
            if let last = transactions.last, last.createdAt.timeIntervalSince1970 < TimeInterval(targetTimestamp) {
                break
            }
            if let target = matchingSectionId(for: date) {
                pendingScrollTarget = target
                return
            }
        }

        if let target = matchingSectionId(for: date) ?? nearestSectionId(for: date) {
            pendingScrollTarget = target
        }
    }

    private func scrollToEnd() async {
        while hasMore {
            await loadNextPage()
        }
        if let last = groupedTransactions.last?.date {
            pendingScrollTarget = last
        }
    }

    private func matchingSectionId(for date: Date) -> String? {
        let cal = Calendar.current
        for section in groupedTransactions {
            guard let secDate = sectionDateParser.date(from: section.date) else { continue }
            if cal.isDate(secDate, inSameDayAs: date) { return section.date }
        }
        return nil
    }

    private func nearestSectionId(for date: Date) -> String? {
        var bestId: String?
        var bestDistance = TimeInterval.infinity
        for section in groupedTransactions {
            guard let secDate = sectionDateParser.date(from: section.date) else { continue }
            let distance = abs(secDate.timeIntervalSince(date))
            if distance < bestDistance {
                bestDistance = distance
                bestId = section.date
            }
        }
        return bestId
    }
}

// MARK: - Initial Fetch Progress Banner

private struct InitialFetchProgressBanner: View {
    let pages: Int
    let rows: Int
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Syncing transactions…")
                        .font(.subheadline.weight(.medium))
                    Text("\(pages) page\(pages == 1 ? "" : "s") · \(rows) loaded · \(formatElapsed(elapsed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let m = total / 60
        let s = total % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return "\(s)s"
    }
}
