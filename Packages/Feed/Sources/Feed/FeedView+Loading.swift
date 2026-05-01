import Database
import Servicing
import SwiftUI

extension FeedView {
    func initialLoad() async {
        await reloadFirstPage()

        // Full sync runs once per install (or until it succeeds end-to-end).
        // After that, only pull new transactions on launch / pull-to-refresh.
        if UserDefaults.standard.bool(forKey: initialSyncCompletedKey) {
            await refreshNewTransactions()
        } else {
            startInitialFetchTask()
        }
    }

    func startInitialFetchTask() {
        guard initialFetchTask == nil else { return }
        initialFetchTask = Task { @MainActor in
            await fetchAllFromServer()
            initialFetchTask = nil
        }
    }

    func fetchAllFromServer() async {
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
            feedLogger.debug("Initial fetch starting, resume token: \(token ?? "nil")")
            repeat {
                try Task.checkCancellation()
                let page = try await transactionService.fetchPage(nextToken: token, perPage: pageSize)
                token = page.nextToken
                initialFetchPages += 1
                initialFetchRows += page.transactions.count
                feedLogger.debug("Initial fetch page \(initialFetchPages), hasMore: \(token != nil)")
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
            feedLogger.info("Initial fetch cancelled")
        } catch {
            if transactions.isEmpty {
                errorMessage = error.localizedDescription
            }
            feedLogger.error("Initial fetch failed: \(error.localizedDescription)")
        }
    }

    func reloadFirstPage() async {
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
            feedLogger.error("reloadFirstPage failed: \(error.localizedDescription)")
        }
    }

    func loadNextPage() async {
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
            feedLogger.error("loadNextPage failed: \(error.localizedDescription)")
        }
    }

    func refreshNewTransactions() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await transactionService.refreshTransactions(perPage: pageSize)
        } catch {
            feedLogger.error("refresh failed: \(error.localizedDescription)")
        }
    }

    /// Reacts to store writes (insert/update/delete). Prepends new top items and patches in-place edits.
    /// Skips full reload while a paginated tail is being loaded to preserve scroll position.
    func handleStoreChange() async {
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
            feedLogger.error("handleStoreChange failed: \(error.localizedDescription)")
        }
    }
}
