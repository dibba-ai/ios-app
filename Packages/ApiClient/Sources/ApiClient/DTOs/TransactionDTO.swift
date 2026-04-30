import Foundation

// MARK: - Transaction DTO

public struct TransactionDTO: Codable, Sendable {
    public let id: String
    public let accountNumber: String?
    public let cardNumber: String?
    public let name: String
    public let merchantCategory: String?
    public let amount: Double
    public let currency: String
    public let success: Bool?
    public let isCredit: Bool?
    public let isDebit: Bool?
    public let isAtm: Bool?
    public let isPurchase: Bool?
    public let isTransfer: Bool?
    public let fullDate: String?
    public let orgType: String?
    public let orgName: String?
    public let transactionType: String?
    public let errorMessage: String?
    public let input: TransactionInputDTO?
    public let metadata: TransactionMetadataDTO?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, amount, currency, success, input, metadata
        case accountNumber = "account_number"
        case cardNumber = "card_number"
        case merchantCategory = "merchant_category"
        case isCredit = "is_credit"
        case isDebit = "is_debit"
        case isAtm = "is_atm"
        case isPurchase = "is_purchase"
        case isTransfer = "is_transfer"
        case fullDate = "full_date"
        case orgType = "org_type"
        case orgName = "org_name"
        case transactionType = "transaction_type"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}

// MARK: - Transaction Input DTO

public struct TransactionInputDTO: Codable, Sendable {
    public let text: String?
    public let from: String?
    public let location: String?
}

// MARK: - Transaction Metadata DTO

public struct TransactionMetadataDTO: Codable, Sendable {
    public let type: String?
    public let identity: TransactionIdentityDTO?
}

public struct TransactionIdentityDTO: Codable, Sendable {
    public let ipAddress: String?
    public let userAgent: String?
}

// MARK: - List Transactions Response

public struct ListTransactionsData: Codable, Sendable {
    public let list: [TransactionDTO]
    public let nextToken: String?
}

public struct ListTransactionsResponse: Codable, Sendable {
    public let listTransactions: ListTransactionsData
}

public struct ListTransactionsVariables: Encodable, Sendable {
    public let nextToken: String?
    public let perPage: Int

    public init(nextToken: String? = nil, perPage: Int = 100) {
        self.nextToken = nextToken
        self.perPage = perPage
    }
}

// MARK: - Create Transaction

public struct CreateTransactionInput: Encodable, Sendable {
    public let name: String
    public let amount: Double
    public let currency: String
    public let isCredit: Bool
    public let isDebit: Bool
    public let isAtm: Bool
    public let isPurchase: Bool
    public let isTransfer: Bool
    public let fullDate: String

    enum CodingKeys: String, CodingKey {
        case name, amount, currency
        case isCredit = "is_credit"
        case isDebit = "is_debit"
        case isAtm = "is_atm"
        case isPurchase = "is_purchase"
        case isTransfer = "is_transfer"
        case fullDate = "full_date"
    }

    public init(
        name: String,
        amount: Double,
        currency: String,
        isCredit: Bool,
        isDebit: Bool,
        isAtm: Bool,
        isPurchase: Bool,
        isTransfer: Bool,
        fullDate: String
    ) {
        self.name = name
        self.amount = amount
        self.currency = currency
        self.isCredit = isCredit
        self.isDebit = isDebit
        self.isAtm = isAtm
        self.isPurchase = isPurchase
        self.isTransfer = isTransfer
        self.fullDate = fullDate
    }
}

public struct CreateTransactionVariables: Encodable, Sendable {
    public let input: CreateTransactionInput

    public init(input: CreateTransactionInput) {
        self.input = input
    }
}

public struct CreateTransactionResponse: Codable, Sendable {
    public let createTransaction: TransactionDTO?
}

// MARK: - Update Transaction

public struct UpdateTransactionInput: Encodable, Sendable {
    public var name: String?
    public var amount: Double?
    public var currency: String?

    public init(
        name: String? = nil,
        amount: Double? = nil,
        currency: String? = nil
    ) {
        self.name = name
        self.amount = amount
        self.currency = currency
    }
}

public struct UpdateTransactionVariables: Encodable, Sendable {
    public let id: String
    public let input: UpdateTransactionInput

    public init(id: String, input: UpdateTransactionInput) {
        self.id = id
        self.input = input
    }
}

public struct UpdateTransactionResponse: Codable, Sendable {
    public let updateTransaction: TransactionDTO
}

// MARK: - Delete Transaction

public struct DeleteTransactionVariables: Encodable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct DeleteTransactionResult: Codable, Sendable {
    public let success: Bool
    public let message: String?
}

public struct DeleteTransactionResponse: Codable, Sendable {
    public let deleteTransaction: DeleteTransactionResult
}
