import Foundation
import Database

// MARK: - Transaction <-> TransactionRecord Mapping

private let payloadEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}()

private let payloadDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

public extension TransactionRecord {
    init(from transaction: Transaction) {
        let payload: Data
        do {
            payload = try payloadEncoder.encode(transaction)
        } catch {
            payload = Data("{}".utf8)
        }

        self.init(
            id: transaction.id,
            fullDate: transaction.fullDate,
            createdAt: Int64(transaction.createdAt.timeIntervalSince1970),
            name: transaction.name,
            orgName: transaction.orgName,
            orgType: transaction.orgType,
            merchantCategory: transaction.merchantCategory,
            amount: transaction.amount,
            currency: transaction.currency,
            transactionType: transaction.transactionType.rawValue,
            transactionTypeDisplay: transaction.computedType.displayName,
            formattedAmount: transaction.formattedAmount,
            isCredit: transaction.isCredit,
            isDebit: transaction.isDebit,
            isAtm: transaction.isAtm,
            isPurchase: transaction.isPurchase,
            isTransfer: transaction.isTransfer,
            success: transaction.success,
            payload: payload
        )
    }
}

public extension Transaction {
    init?(from record: TransactionRecord) {
        if let decoded = try? payloadDecoder.decode(Transaction.self, from: record.payload) {
            self = decoded
            return
        }

        // Fallback if payload is missing/corrupt: rebuild from promoted columns.
        let type = TransactionType(rawValue: record.transactionType) ?? .unknown
        self.init(
            id: record.id,
            name: record.name,
            merchantCategory: record.merchantCategory,
            amount: record.amount,
            currency: record.currency,
            success: record.success,
            isCredit: record.isCredit,
            isDebit: record.isDebit,
            isAtm: record.isAtm,
            isPurchase: record.isPurchase,
            isTransfer: record.isTransfer,
            fullDate: record.fullDate,
            orgType: record.orgType,
            orgName: record.orgName,
            transactionType: type,
            createdAt: Date(timeIntervalSince1970: TimeInterval(record.createdAt))
        )
    }
}
