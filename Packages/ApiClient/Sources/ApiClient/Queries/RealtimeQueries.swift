import Foundation

// MARK: - Realtime Queries

public enum RealtimeQueries {
    public static let realtimeOptions = """
        query realtimeOptions {
            realtimeOptions {
                voices {
                    voice
                    provider
                    name
                    emoji
                    gender
                }
            }
        }
        """

    /// Builds the `createRealtimeSession` mutation with the input literal inlined.
    /// `provider` and `vibe` are GraphQL enums (unquoted); `voice` is a string.
    /// Backend does not expose an `Input` type name we can declare as a variable,
    /// so we bake the values directly into the query string.
    public static func createRealtimeSession(provider: String, voice: String, vibe: String? = nil) -> String {
        let safeProvider = provider.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let safeVoice = voice.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        var fields = "provider: \(safeProvider), voice: \"\(safeVoice)\""
        if let vibe, !vibe.isEmpty {
            let safeVibe = vibe.filter { $0.isLetter || $0.isNumber || $0 == "_" }
            if !safeVibe.isEmpty {
                fields += ", vibe: \(safeVibe)"
            }
        }
        return """
            mutation createRealtimeSession {
                createRealtimeSession(input: {\(fields)}) {
                    id
                    endpoint
                    model
                    provider
                    token
                    tokenExpiresAt
                }
            }
            """
    }
}
