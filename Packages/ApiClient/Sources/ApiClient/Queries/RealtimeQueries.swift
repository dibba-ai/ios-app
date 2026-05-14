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
    /// The backend exposes `provider` as an enum (unquoted) and currently does not
    /// expose an `Input` type name we can declare as a variable, so we bake the
    /// values directly into the query string.
    public static func createRealtimeSession(provider: String, voice: String) -> String {
        // Sanitise to defensively avoid breaking the query; both fields should
        // only ever contain `[A-Za-z0-9_-]`.
        let safeProvider = provider.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let safeVoice = voice.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return """
            mutation createRealtimeSession {
                createRealtimeSession(input: {provider: \(safeProvider), voice: "\(safeVoice)"}) {
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
