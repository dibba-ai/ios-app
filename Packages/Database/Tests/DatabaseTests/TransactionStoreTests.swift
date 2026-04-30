import Foundation
import Testing
@testable import Database

@Suite("TransactionStore")
struct TransactionStoreTests {
    private func makeStore() throws -> TransactionStore {
        let db = try AppDatabase.makeInMemory()
        return TransactionStore(database: db)
    }

    private func makeRecord(
        id: String = UUID().uuidString,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        name: String = "Acme Coffee",
        orgName: String = "Acme",
        merchantCategory: String = "Cafe",
        type: String = "pos_purchase",
        typeDisplay: String = "Purchase",
        amount: Double = -4.50,
        currency: String = "USD"
    ) -> TransactionRecord {
        TransactionRecord(
            id: id,
            fullDate: "2026-04-29",
            createdAt: createdAt,
            name: name,
            orgName: orgName,
            orgType: "merchant",
            merchantCategory: merchantCategory,
            amount: amount,
            currency: currency,
            transactionType: type,
            transactionTypeDisplay: typeDisplay,
            formattedAmount: "$4.50",
            isCredit: amount > 0,
            isDebit: amount < 0,
            isAtm: false,
            isPurchase: type == "pos_purchase",
            isTransfer: type == "transfer",
            success: true,
            payload: Data("{}".utf8)
        )
    }

    @Test
    func upsertAndCount() async throws {
        let store = try makeStore()
        try await store.upsert([makeRecord(id: "1"), makeRecord(id: "2")])

        let count = try await store.count(filter: TransactionFilter())
        #expect(count == 2)
    }

    @Test
    func upsertReplaces() async throws {
        let store = try makeStore()
        try await store.upsert([makeRecord(id: "1", name: "Old")])
        try await store.upsert([makeRecord(id: "1", name: "New")])

        let page = try await store.page(filter: TransactionFilter(), limit: 10, after: nil)
        #expect(page.records.count == 1)
        #expect(page.records[0].name == "New")
    }

    @Test
    func deleteRemovesRow() async throws {
        let store = try makeStore()
        try await store.upsert([makeRecord(id: "1"), makeRecord(id: "2")])
        try await store.delete(id: "1")

        let count = try await store.count(filter: TransactionFilter())
        #expect(count == 1)
    }

    @Test
    func clearRemovesAll() async throws {
        let store = try makeStore()
        try await store.upsert([makeRecord(id: "1"), makeRecord(id: "2")])
        try await store.clear()

        let count = try await store.count(filter: TransactionFilter())
        #expect(count == 0)
    }

    @Test
    func paginationOrdersByCreatedAtDesc() async throws {
        let store = try makeStore()
        let records = (0..<5).map { i in
            makeRecord(id: "\(i)", createdAt: Int64(1_700_000_000 + i))
        }
        try await store.upsert(records)

        let first = try await store.page(filter: TransactionFilter(), limit: 2, after: nil)
        #expect(first.records.map(\.id) == ["4", "3"])
        #expect(first.nextCursor != nil)

        let second = try await store.page(filter: TransactionFilter(), limit: 2, after: first.nextCursor)
        #expect(second.records.map(\.id) == ["2", "1"])

        let third = try await store.page(filter: TransactionFilter(), limit: 2, after: second.nextCursor)
        #expect(third.records.map(\.id) == ["0"])
        #expect(third.nextCursor == nil)
    }

    @Test
    func filterByType() async throws {
        let store = try makeStore()
        try await store.upsert([
            makeRecord(id: "1", type: "pos_purchase"),
            makeRecord(id: "2", type: "transfer"),
        ])

        let page = try await store.page(
            filter: TransactionFilter(types: ["transfer"]),
            limit: 10,
            after: nil
        )
        #expect(page.records.map(\.id) == ["2"])
    }

    @Test
    func searchMatchesNamePrefix() async throws {
        let store = try makeStore()
        try await store.upsert([
            makeRecord(id: "1", name: "Acme Coffee", orgName: "Acme"),
            makeRecord(id: "2", name: "Bagel Place", orgName: "Bagel"),
        ])

        let page = try await store.page(
            filter: TransactionFilter(search: "acm"),
            limit: 10,
            after: nil
        )
        #expect(page.records.map(\.id) == ["1"])
    }

    @Test
    func searchMatchesOrgName() async throws {
        let store = try makeStore()
        try await store.upsert([
            makeRecord(id: "1", orgName: "Starbucks"),
            makeRecord(id: "2", orgName: "Whole Foods"),
        ])

        let page = try await store.page(
            filter: TransactionFilter(search: "whole"),
            limit: 10,
            after: nil
        )
        #expect(page.records.map(\.id) == ["2"])
    }

    @Test
    func filterByDateRange() async throws {
        let store = try makeStore()
        try await store.upsert([
            makeRecord(id: "1", createdAt: 1_700_000_000),
            makeRecord(id: "2", createdAt: 1_700_001_000),
            makeRecord(id: "3", createdAt: 1_700_002_000),
        ])

        let lower = Date(timeIntervalSince1970: 1_700_000_500)
        let upper = Date(timeIntervalSince1970: 1_700_001_500)
        let page = try await store.page(
            filter: TransactionFilter(dateRange: lower...upper),
            limit: 10,
            after: nil
        )
        #expect(page.records.map(\.id) == ["2"])
    }
}
