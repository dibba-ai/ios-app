import Foundation
import GRDB

// MARK: - Transaction Record

/// Database row for a stored transaction. Independent of the `Servicing.Transaction`
/// domain model so this package has no dependency on `Servicing`. Callers map at the boundary.
public struct TransactionRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public static let databaseTableName = "transaction_record"

    public var id: String
    public var fullDate: String
    public var createdAt: Int64
    public var name: String
    public var orgName: String
    public var orgType: String
    public var merchantCategory: String
    public var amount: Double
    public var currency: String
    public var transactionType: String
    public var transactionTypeDisplay: String
    public var formattedAmount: String
    public var isCredit: Bool
    public var isDebit: Bool
    public var isAtm: Bool
    public var isPurchase: Bool
    public var isTransfer: Bool
    public var success: Bool
    public var payload: Data

    public init(
        id: String,
        fullDate: String,
        createdAt: Int64,
        name: String,
        orgName: String,
        orgType: String,
        merchantCategory: String,
        amount: Double,
        currency: String,
        transactionType: String,
        transactionTypeDisplay: String,
        formattedAmount: String,
        isCredit: Bool,
        isDebit: Bool,
        isAtm: Bool,
        isPurchase: Bool,
        isTransfer: Bool,
        success: Bool,
        payload: Data
    ) {
        self.id = id
        self.fullDate = fullDate
        self.createdAt = createdAt
        self.name = name
        self.orgName = orgName
        self.orgType = orgType
        self.merchantCategory = merchantCategory
        self.amount = amount
        self.currency = currency
        self.transactionType = transactionType
        self.transactionTypeDisplay = transactionTypeDisplay
        self.formattedAmount = formattedAmount
        self.isCredit = isCredit
        self.isDebit = isDebit
        self.isAtm = isAtm
        self.isPurchase = isPurchase
        self.isTransfer = isTransfer
        self.success = success
        self.payload = payload
    }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let fullDate = Column(CodingKeys.fullDate)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let name = Column(CodingKeys.name)
        public static let orgName = Column(CodingKeys.orgName)
        public static let orgType = Column(CodingKeys.orgType)
        public static let merchantCategory = Column(CodingKeys.merchantCategory)
        public static let amount = Column(CodingKeys.amount)
        public static let currency = Column(CodingKeys.currency)
        public static let transactionType = Column(CodingKeys.transactionType)
        public static let transactionTypeDisplay = Column(CodingKeys.transactionTypeDisplay)
        public static let formattedAmount = Column(CodingKeys.formattedAmount)
        public static let isCredit = Column(CodingKeys.isCredit)
        public static let isDebit = Column(CodingKeys.isDebit)
        public static let isAtm = Column(CodingKeys.isAtm)
        public static let isPurchase = Column(CodingKeys.isPurchase)
        public static let isTransfer = Column(CodingKeys.isTransfer)
        public static let success = Column(CodingKeys.success)
        public static let payload = Column(CodingKeys.payload)
    }
}

// MARK: - Filter & Cursor

public struct TransactionFilter: Equatable, Sendable {
    public var search: String?
    public var types: Set<String>?
    public var dateRange: ClosedRange<Date>?

    public init(
        search: String? = nil,
        types: Set<String>? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) {
        self.search = search
        self.types = types
        self.dateRange = dateRange
    }

    public var isEmpty: Bool {
        (search?.isEmpty ?? true) && (types?.isEmpty ?? true) && dateRange == nil
    }
}

public struct TransactionCursor: Equatable, Sendable {
    public let createdAt: Int64
    public let id: String

    public init(createdAt: Int64, id: String) {
        self.createdAt = createdAt
        self.id = id
    }
}

public struct TransactionPage: Equatable, Sendable {
    public let records: [TransactionRecord]
    public let nextCursor: TransactionCursor?

    public init(records: [TransactionRecord], nextCursor: TransactionCursor?) {
        self.records = records
        self.nextCursor = nextCursor
    }
}
