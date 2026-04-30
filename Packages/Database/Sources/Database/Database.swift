import Foundation
import GRDB

// MARK: - AppDatabase

/// Owns the GRDB connection pool and migration setup.
public final class AppDatabase: @unchecked Sendable {
    public let writer: DatabaseWriter

    public init(_ writer: DatabaseWriter) throws {
        self.writer = writer
        var migrator = DatabaseMigrator()
        Migrations.register(&migrator)
        try migrator.migrate(writer)
    }

    /// Live, on-disk database in `Application Support/Database/dibba.sqlite`.
    public static func makeDefault() throws -> AppDatabase {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Database", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("dibba.sqlite")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL;")
        }

        let pool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(pool)
    }

    /// In-memory database for tests and previews.
    public static func makeInMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue()
        return try AppDatabase(queue)
    }
}
