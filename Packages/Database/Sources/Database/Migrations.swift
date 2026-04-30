import Foundation
import GRDB

enum Migrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_transactions") { db in
            try db.create(table: TransactionRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("fullDate", .text).notNull()
                t.column("createdAt", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("orgName", .text).notNull().defaults(to: "")
                t.column("orgType", .text).notNull().defaults(to: "")
                t.column("merchantCategory", .text).notNull().defaults(to: "")
                t.column("amount", .double).notNull()
                t.column("currency", .text).notNull()
                t.column("transactionType", .text).notNull()
                t.column("transactionTypeDisplay", .text).notNull()
                t.column("formattedAmount", .text).notNull()
                t.column("isCredit", .boolean).notNull().defaults(to: false)
                t.column("isDebit", .boolean).notNull().defaults(to: false)
                t.column("isAtm", .boolean).notNull().defaults(to: false)
                t.column("isPurchase", .boolean).notNull().defaults(to: false)
                t.column("isTransfer", .boolean).notNull().defaults(to: false)
                t.column("success", .boolean).notNull().defaults(to: true)
                t.column("payload", .blob).notNull()
            }

            try db.create(
                index: "ix_tx_createdAt",
                on: TransactionRecord.databaseTableName,
                columns: ["createdAt"]
            )
            try db.create(
                index: "ix_tx_fullDate",
                on: TransactionRecord.databaseTableName,
                columns: ["fullDate"]
            )
            try db.create(
                index: "ix_tx_type",
                on: TransactionRecord.databaseTableName,
                columns: ["transactionType"]
            )

            try db.create(
                virtualTable: "transaction_fts",
                using: FTS5()
            ) { t in
                t.tokenizer = .unicode61(diacritics: .removeLegacy)
                t.column("name")
                t.column("orgName")
                t.column("merchantCategory")
                t.column("transactionTypeDisplay")
                t.column("formattedAmount")
                t.synchronize(withTable: TransactionRecord.databaseTableName)
            }
        }
    }
}
