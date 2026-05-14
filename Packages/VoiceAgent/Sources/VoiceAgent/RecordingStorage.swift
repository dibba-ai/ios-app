import Foundation
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "VoiceAgent.Storage")

public protocol RecordingStorage: Sendable {
    /// Returns the URL where the recorder should write audio bytes for a brand new
    /// recording. Reserved on disk before recording starts.
    func makeAudioURL(for id: UUID) -> URL

    func save(_ metadata: RecordingMetadata) throws
    func update(_ metadata: RecordingMetadata) throws
    func fetchAll() throws -> [RecordingMetadata]
    func delete(id: UUID) throws

    /// Removes recordings (metadata + audio files) whose `createdAt` is older than
    /// `maxAge` from `referenceDate`.
    @discardableResult
    func purgeOlderThan(maxAge: TimeInterval, referenceDate: Date) throws -> Int
}

/// On-disk implementation: audio files live in `<Documents>/VoiceAgent/`, metadata
/// is persisted as a JSON index alongside the files.
public final class FileSystemRecordingStorage: RecordingStorage, @unchecked Sendable {
    private static let directoryName = "VoiceAgent"
    private static let indexFileName = "index.json"

    private let directory: URL
    private let indexURL: URL
    private let queue = DispatchQueue(label: "ai.dibba.voiceagent.storage")
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.directory = documents.appendingPathComponent(Self.directoryName, isDirectory: true)
        self.indexURL = directory.appendingPathComponent(Self.indexFileName)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: indexURL.path) {
            try writeIndex([])
        }
    }

    public func makeAudioURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).caf")
    }

    public func save(_ metadata: RecordingMetadata) throws {
        try queue.sync {
            var index = try readIndex()
            index.removeAll { $0.id == metadata.id }
            index.append(metadata)
            try writeIndex(index)
        }
    }

    public func update(_ metadata: RecordingMetadata) throws {
        try save(metadata)
    }

    public func fetchAll() throws -> [RecordingMetadata] {
        try queue.sync { try readIndex() }
    }

    public func delete(id: UUID) throws {
        try queue.sync {
            var index = try readIndex()
            if let removed = index.first(where: { $0.id == id }) {
                let audioURL = directory.appendingPathComponent(removed.audioFileName)
                try? fileManager.removeItem(at: audioURL)
            }
            index.removeAll { $0.id == id }
            try writeIndex(index)
        }
    }

    @discardableResult
    public func purgeOlderThan(maxAge: TimeInterval, referenceDate: Date) throws -> Int {
        try queue.sync {
            var index = try readIndex()
            let cutoff = referenceDate.addingTimeInterval(-maxAge)
            let expired = index.filter { $0.createdAt < cutoff }
            for item in expired {
                let audioURL = directory.appendingPathComponent(item.audioFileName)
                try? fileManager.removeItem(at: audioURL)
            }
            index.removeAll { item in expired.contains(where: { $0.id == item.id }) }
            try writeIndex(index)
            if !expired.isEmpty {
                logger.info("purged \(expired.count) expired recordings")
            }
            return expired.count
        }
    }

    private func readIndex() throws -> [RecordingMetadata] {
        let data = try Data(contentsOf: indexURL)
        if data.isEmpty { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([RecordingMetadata].self, from: data)
    }

    private func writeIndex(_ records: [RecordingMetadata]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: indexURL, options: .atomic)
    }
}
