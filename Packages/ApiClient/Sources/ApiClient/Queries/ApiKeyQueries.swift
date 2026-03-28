import Foundation

// MARK: - API Key Queries

public enum ApiKeyQueries {
    private static let apiKeyFields = """
        id
        name
        active
        created_at
        created_at_iso
        """

    public static let listApiKeys = """
        query listApiKeys {
            listApiKeys {
                \(apiKeyFields)
            }
        }
        """

    public static let createApiKey = """
        mutation createApiKey($input: ApiKeyInput!) {
            createApiKey(input: $input) {
                \(apiKeyFields)
            }
        }
        """
}
