import Foundation
import GRDB
import Dependencies

// MARK: - Store Protocol

public protocol TransactionStoring: Sendable {
    func upsert(_ records: [TransactionRecord]) async throws
    func delete(id: String) async throws
    func clear() async throws
    func count(filter: TransactionFilter) async throws -> Int
    func contains(id: String) async throws -> Bool
    func existingIds(in ids: [String]) async throws -> Set<String>
    func page(filter: TransactionFilter, limit: Int, after cursor: TransactionCursor?) async throws -> TransactionPage
    func firstByCreatedAtAscending(filter: TransactionFilter) async throws -> TransactionRecord?
    func observeAll() -> AsyncStream<[TransactionRecord]>
    func observeChanges() -> AsyncStream<Void>
}

// MARK: - GRDB Implementation

public struct TransactionStore: TransactionStoring {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: Writes

    public func upsert(_ records: [TransactionRecord]) async throws {
        guard !records.isEmpty else { return }
        try await database.writer.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    public func delete(id: String) async throws {
        _ = try await database.writer.write { db in
            try TransactionRecord.deleteOne(db, key: id)
        }
    }

    public func clear() async throws {
        try await database.writer.write { db in
            _ = try TransactionRecord.deleteAll(db)
        }
    }

    // MARK: Reads

    public func count(filter: TransactionFilter) async throws -> Int {
        try await database.writer.read { db in
            try fetchRequest(filter: filter).fetchCount(db)
        }
    }

    public func contains(id: String) async throws -> Bool {
        try await database.writer.read { db in
            try TransactionRecord.filter(TransactionRecord.Columns.id == id).fetchCount(db) > 0
        }
    }

    public func existingIds(in ids: [String]) async throws -> Set<String> {
        guard !ids.isEmpty else { return [] }
        return try await database.writer.read { db in
            let rows = try TransactionRecord
                .filter(ids.contains(TransactionRecord.Columns.id))
                .select(TransactionRecord.Columns.id, as: String.self)
                .fetchAll(db)
            return Set(rows)
        }
    }

    public func page(
        filter: TransactionFilter,
        limit: Int,
        after cursor: TransactionCursor?
    ) async throws -> TransactionPage {
        try await database.writer.read { db in
            let fetchLimit = limit < Int.max ? limit + 1 : limit
            var request = fetchRequest(filter: filter)
                .order(TransactionRecord.Columns.createdAt.desc, TransactionRecord.Columns.id.desc)
                .limit(fetchLimit)

            if let cursor {
                request = request.filter(
                    sql: "(createdAt < ?) OR (createdAt = ? AND id < ?)",
                    arguments: [cursor.createdAt, cursor.createdAt, cursor.id]
                )
            }

            let rows = try request.fetchAll(db)
            let hasMore = rows.count > limit
            let pageRows = hasMore ? Array(rows.prefix(limit)) : rows
            let next = hasMore
                ? pageRows.last.map { TransactionCursor(createdAt: $0.createdAt, id: $0.id) }
                : nil
            return TransactionPage(records: pageRows, nextCursor: next)
        }
    }

    public func firstByCreatedAtAscending(filter: TransactionFilter) async throws -> TransactionRecord? {
        try await database.writer.read { db in
            try fetchRequest(filter: filter)
                .order(TransactionRecord.Columns.createdAt.asc, TransactionRecord.Columns.id.asc)
                .fetchOne(db)
        }
    }

    public func observeChanges() -> AsyncStream<Void> {
        let observation = DatabaseRegionObservation(tracking: TransactionRecord.all())
        let writer = database.writer
        return AsyncStream { continuation in
            let box = CancellableBox()
            do {
                box.cancellable = try observation.start(
                    in: writer,
                    onError: { _ in continuation.finish() },
                    onChange: { _ in continuation.yield(()) }
                )
            } catch {
                continuation.finish()
            }
            continuation.onTermination = { _ in box.cancel() }
        }
    }

    public func observeAll() -> AsyncStream<[TransactionRecord]> {
        let observation = ValueObservation.tracking { db in
            try TransactionRecord
                .order(TransactionRecord.Columns.createdAt.desc)
                .fetchAll(db)
        }
        let writer = database.writer
        return AsyncStream { continuation in
            let box = CancellableBox()
            box.cancellable = observation.start(
                in: writer,
                onError: { _ in continuation.finish() },
                onChange: { records in continuation.yield(records) }
            )
            continuation.onTermination = { _ in
                box.cancel()
            }
        }
    }

    // MARK: Filter

    private func fetchRequest(filter: TransactionFilter) -> QueryInterfaceRequest<TransactionRecord> {
        var request = TransactionRecord.all()

        if let types = filter.types, !types.isEmpty {
            request = request.filter(types.contains(TransactionRecord.Columns.transactionType))
        }

        if let range = filter.dateRange {
            let lower = Int64(range.lowerBound.timeIntervalSince1970)
            let upper = Int64(range.upperBound.timeIntervalSince1970)
            request = request.filter(
                TransactionRecord.Columns.createdAt >= lower
                && TransactionRecord.Columns.createdAt <= upper
            )
        }

        if let raw = filter.search?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let match = Self.ftsMatchPattern(for: raw)
            request = request.filter(
                sql: "rowid IN (SELECT rowid FROM transaction_fts WHERE transaction_fts MATCH ?)",
                arguments: [match]
            )
        }

        return request
    }

    private static func ftsMatchPattern(for query: String) -> String {
        // Tokenize by whitespace, escape quotes, append `*` for prefix match.
        let tokens = query
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "" }
        return tokens
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " ")
    }
}

// MARK: - Cancellable Wrapper

private final class CancellableBox: @unchecked Sendable {
    var cancellable: AnyDatabaseCancellable?
    func cancel() { cancellable?.cancel(); cancellable = nil }
}

// MARK: - Dependency

extension TransactionStore: TestDependencyKey {
    public static let testValue: any TransactionStoring = {
        let db = try! AppDatabase.makeInMemory()
        return TransactionStore(database: db)
    }()
}

public extension DependencyValues {
    var transactionStore: any TransactionStoring {
        get { self[TransactionStoreKey.self] }
        set { self[TransactionStoreKey.self] = newValue }
    }
}

public enum TransactionStoreKey: DependencyKey {
    public static let liveValue: any TransactionStoring = {
        do {
            let db = try AppDatabase.makeDefault()
            return TransactionStore(database: db)
        } catch {
            // Fall back to in-memory so the app still boots if the on-disk DB cannot open.
            let db = try! AppDatabase.makeInMemory()
            return TransactionStore(database: db)
        }
    }()
    public static let testValue: any TransactionStoring = {
        let db = try! AppDatabase.makeInMemory()
        return TransactionStore(database: db)
    }()
}
