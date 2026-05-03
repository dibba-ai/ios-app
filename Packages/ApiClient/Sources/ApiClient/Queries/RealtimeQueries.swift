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
}
