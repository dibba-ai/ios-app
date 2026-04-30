import Foundation
import Dependencies
import ApiClient
import Database
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TransactionService")

// MARK: - Initial Sync Defaults Keys

public enum InitialSyncDefaults {
    public static let completedKey = "feed.initialSyncCompleted"
    public static let nextTokenKey = "feed.initialSyncNextToken"
}

// MARK: - Transaction Service Protocol

public protocol TransactionServicing: Sendable {
    /// Fetch a single page of transactions from the API and append to cache
    func fetchPage(nextToken: String?, perPage: Int) async throws -> TransactionListResult

    /// Load all transactions up to a date
    func loadAllTransactions(untilDate: Date?) async throws -> [Transaction]

    /// Create a new transaction
    func createTransaction(_ input: CreateTransactionInput) async throws -> Transaction

    /// Update an existing transaction
    func updateTransaction(id: String, input: UpdateTransactionInput) async throws -> Transaction

    /// Delete a transaction
    func deleteTransaction(id: String) async throws -> Bool

    /// Get cached transactions
    var cachedTransactions: [Transaction] { get async }

    /// Refresh transactions incrementally (fetch new ones until overlap with cache)
    func refreshTransactions(perPage: Int) async throws -> TransactionListResult

    /// Clear cached data
    func clearCache() async
}

// MARK: - Transaction List Result

public struct TransactionListResult: Sendable {
    public let transactions: [Transaction]
    public let nextToken: String?

    public init(transactions: [Transaction], nextToken: String?) {
        self.transactions = transactions
        self.nextToken = nextToken
    }
}

// MARK: - Transaction Service Implementation

public actor TransactionService: TransactionServicing {
    @Dependency(\.apiClient) private var client
    @Dependency(\.transactionStore) private var store

    private var loadAllTask: Task<[Transaction], any Error>?

    public init() {
        // Best-effort cleanup of legacy on-disk JSON cache from the previous storage layer.
        let url = URL.cachesDirectory.appending(components: "cachedTransactions.json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Public Methods

    public var cachedTransactions: [Transaction] {
        get async {
            do {
                let page = try await store.page(filter: TransactionFilter(), limit: Int.max, after: nil)
                return page.records.compactMap(Transaction.init(from:))
            } catch {
                logger.error("cachedTransactions failed: \(error.localizedDescription)")
                return []
            }
        }
    }

    public func fetchPage(nextToken: String? = nil, perPage: Int = 100) async throws -> TransactionListResult {
        logger.debug("fetchPage called, nextToken: \(nextToken ?? "nil"), perPage: \(perPage)")

        let data = try await client.listTransactions(nextToken: nextToken, perPage: perPage)
        let page = data.list.map { Transaction(from: $0) }

        try await store.upsert(page.map(TransactionRecord.init(from:)))
        logger.debug("fetchPage: upserted \(page.count) records")

        return TransactionListResult(transactions: page, nextToken: data.nextToken)
    }

    public func refreshTransactions(perPage: Int = 100) async throws -> TransactionListResult {
        let cachedCount = (try? await store.count(filter: TransactionFilter())) ?? 0
        guard cachedCount > 0 else {
            logger.debug("refreshTransactions: empty store, loading all pages")
            var token: String? = nil
            repeat {
                let page = try await fetchPage(nextToken: token, perPage: perPage)
                token = page.nextToken
            } while token != nil
            return TransactionListResult(transactions: await cachedTransactions, nextToken: nil)
        }

        var newTransactions: [Transaction] = []
        var pageToken: String? = nil
        var foundOverlap = false

        logger.info("refreshTransactions: checking for new transactions, cached count: \(cachedCount)")

        repeat {
            let data = try await client.listTransactions(nextToken: pageToken, perPage: perPage)
            let page = data.list.map { Transaction(from: $0) }
            logger.debug("refreshTransactions: fetched page with \(page.count) transactions")

            let pageIds = page.map(\.id)
            let existing = (try? await store.existingIds(in: pageIds)) ?? []

            for transaction in page {
                if existing.contains(transaction.id) {
                    foundOverlap = true
                    break
                }
                newTransactions.append(transaction)
            }

            if foundOverlap { break }
            pageToken = data.nextToken
        } while pageToken != nil

        logger.info("refreshTransactions: found \(newTransactions.count) new transactions")

        if !newTransactions.isEmpty {
            try await store.upsert(newTransactions.map(TransactionRecord.init(from:)))
        }

        return TransactionListResult(transactions: await cachedTransactions, nextToken: nil)
    }

    public func loadAllTransactions(untilDate: Date? = nil) async throws -> [Transaction] {
        if let loadAllTask {
            return try await loadAllTask.value
        }

        let task = Task<[Transaction], any Error> {
            var allTransactions: [Transaction] = []
            var nextToken: String? = nil
            let targetTimestamp = (untilDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()))!.timeIntervalSince1970

            repeat {
                let result = try await client.listTransactions(nextToken: nextToken, perPage: 100)
                let transactions = result.list.map { Transaction(from: $0) }
                allTransactions.append(contentsOf: transactions)

                if let lastTransaction = transactions.last,
                   lastTransaction.createdAt.timeIntervalSince1970 < targetTimestamp {
                    break
                }

                nextToken = result.nextToken
            } while nextToken != nil

            return allTransactions
        }

        loadAllTask = task
        defer { loadAllTask = nil }

        let transactions = try await task.value
        try await store.upsert(transactions.map(TransactionRecord.init(from:)))
        return transactions
    }

    public func createTransaction(_ input: CreateTransactionInput) async throws -> Transaction {
        let dto = try await client.createTransaction(input: input)
        let transaction = Transaction(from: dto)
        try await store.upsert([TransactionRecord(from: transaction)])
        return transaction
    }

    public func updateTransaction(id: String, input: UpdateTransactionInput) async throws -> Transaction {
        let dto = try await client.updateTransaction(id: id, input: input)
        let transaction = Transaction(from: dto)
        try await store.upsert([TransactionRecord(from: transaction)])
        return transaction
    }

    public func deleteTransaction(id: String) async throws -> Bool {
        let success = try await client.deleteTransaction(id: id)
        if success {
            try await store.delete(id: id)
        }
        return success
    }

    public func clearCache() async {
        do {
            try await store.clear()
        } catch {
            logger.error("clearCache failed: \(error.localizedDescription)")
        }
        loadAllTask?.cancel()
        loadAllTask = nil
        UserDefaults.standard.removeObject(forKey: InitialSyncDefaults.completedKey)
        UserDefaults.standard.removeObject(forKey: InitialSyncDefaults.nextTokenKey)
    }
}

// MARK: - Transaction Conversion

extension Transaction {
    init(from dto: TransactionDTO) {
        let transactionType: TransactionType
        if let typeString = dto.transactionType {
            transactionType = TransactionType(rawValue: typeString) ?? .unknown
        } else if dto.isPurchase == true {
            transactionType = .posPurchase
        } else if dto.isTransfer == true {
            transactionType = .transfer
        } else if dto.isAtm == true {
            transactionType = .atm
        } else {
            transactionType = .unknown
        }

        self.init(
            id: dto.id,
            accountNumber: dto.accountNumber ?? "",
            cardNumber: dto.cardNumber ?? "",
            name: dto.name,
            merchantCategory: dto.merchantCategory ?? "",
            amount: dto.amount,
            currency: dto.currency,
            success: dto.success ?? true,
            isCredit: dto.isCredit ?? false,
            isDebit: dto.isDebit ?? false,
            isAtm: dto.isAtm ?? false,
            isPurchase: dto.isPurchase ?? false,
            isTransfer: dto.isTransfer ?? false,
            fullDate: dto.fullDate ?? "",
            orgType: dto.orgType ?? "",
            orgName: dto.orgName ?? "",
            transactionType: transactionType,
            errorMessage: dto.errorMessage,
            input: dto.input.map { TransactionInput(from: $0) },
            metadata: dto.metadata.map { TransactionMetadata(from: $0) },
            createdAt: dto.createdAt ?? Date()
        )
    }
}

extension TransactionInput {
    init(from dto: TransactionInputDTO) {
        self.init(
            text: dto.text,
            from: dto.from,
            location: dto.location
        )
    }
}

extension TransactionMetadata {
    init(from dto: TransactionMetadataDTO) {
        self.init(
            type: dto.type ?? "unknown",
            userAgent: dto.identity?.userAgent,
            ipAddress: dto.identity?.ipAddress
        )
    }
}

// MARK: - Dependency Registration

extension TransactionService: DependencyKey {
    public static let liveValue: any TransactionServicing = TransactionService()
    public static let testValue: any TransactionServicing = TransactionService()
}

public extension DependencyValues {
    var transactionService: any TransactionServicing {
        get { self[TransactionService.self] }
        set { self[TransactionService.self] = newValue }
    }
}
