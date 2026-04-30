import Foundation

// MARK: - API Key

public struct ApiKey: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let active: Bool
    public let createdAt: Date
    public let createdAtTimestamp: Int?

    public init(
        id: String,
        name: String,
        active: Bool = true,
        createdAt: Date = Date(),
        createdAtTimestamp: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.active = active
        self.createdAt = createdAt
        self.createdAtTimestamp = createdAtTimestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, name, active
        case createdAt = "created_at_iso"
        case createdAtTimestamp = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        active = try container.decode(Bool.self, forKey: .active)
        createdAtTimestamp = try container.decodeIfPresent(Int.self, forKey: .createdAtTimestamp)

        // Try to decode ISO string first, fall back to timestamp
        if let isoString = try container.decodeIfPresent(String.self, forKey: .createdAt),
           let date = Self.parseISO8601(isoString) {
            createdAt = date
        } else if let timestamp = createdAtTimestamp {
            createdAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            createdAt = Date()
        }
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Computed Properties

public extension ApiKey {
    var isActive: Bool { active }

    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var maskedId: String {
        guard id.count > 8 else { return String(repeating: "•", count: id.count) }
        let prefix = String(id.prefix(4))
        let suffix = String(id.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}

// MARK: - Factory

public extension ApiKey {
    static func makeApiKey(
        id: String = UUID().uuidString,
        name: String = "My API Key",
        active: Bool = true
    ) -> ApiKey {
        ApiKey(
            id: id,
            name: name,
            active: active,
            createdAt: Date()
        )
    }
}
