import Foundation
import Dependencies
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "GraphQLClient")

// MARK: - GraphQL Client Protocol

public protocol GraphQLClientProtocol: Sendable {
    func execute<T: Decodable, V: Encodable & Sendable>(
        query: String,
        variables: V?,
        operationName: String?
    ) async throws -> T
}

// MARK: - GraphQL Client

public final class GraphQLClient: GraphQLClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: TokenProviding
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // Retry configuration
    private let maxRetries: Int
    private let baseDelay: TimeInterval

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: TokenProviding,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.1
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // Try ISO8601 string first
            if let dateString = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                // Try parsing string as Unix timestamp
                if let timestamp = Double(dateString) {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }

            // Try Unix timestamp (seconds)
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            // Try Unix timestamp as Int
            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func execute<T: Decodable, V: Encodable & Sendable>(
        query: String,
        variables: V?,
        operationName: String?
    ) async throws -> T {
        try await executeWithRetry(
            query: query,
            variables: variables,
            operationName: operationName,
            forceTokenRefresh: false,
            retryCount: 0
        )
    }

    private func executeWithRetry<T: Decodable, V: Encodable & Sendable>(
        query: String,
        variables: V?,
        operationName: String?,
        forceTokenRefresh: Bool,
        retryCount: Int
    ) async throws -> T {
        do {
            return try await performRequest(
                query: query,
                variables: variables,
                operationName: operationName,
                forceTokenRefresh: forceTokenRefresh
            )
        } catch let error as APIClientError {
            // Handle 401 - refresh token and retry once
            if error.isUnauthorized && retryCount == 0 {
                return try await executeWithRetry(
                    query: query,
                    variables: variables,
                    operationName: operationName,
                    forceTokenRefresh: true,
                    retryCount: retryCount + 1
                )
            }

            // Handle retryable network errors
            if error.isRetryable && retryCount < maxRetries {
                let delay = baseDelay * pow(2.0, Double(retryCount))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                return try await executeWithRetry(
                    query: query,
                    variables: variables,
                    operationName: operationName,
                    forceTokenRefresh: forceTokenRefresh,
                    retryCount: retryCount + 1
                )
            }

            throw error
        } catch let error as URLError {
            // Convert URLError to APIClientError and retry if applicable
            let apiError = APIClientError.client(error)
            if apiError.isRetryable && retryCount < maxRetries {
                let delay = baseDelay * pow(2.0, Double(retryCount))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                return try await executeWithRetry(
                    query: query,
                    variables: variables,
                    operationName: operationName,
                    forceTokenRefresh: forceTokenRefresh,
                    retryCount: retryCount + 1
                )
            }
            throw apiError
        }
    }

    private func performRequest<T: Decodable, V: Encodable & Sendable>(
        query: String,
        variables: V?,
        operationName: String?,
        forceTokenRefresh: Bool
    ) async throws -> T {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        let token = try await tokenProvider.getToken(forceRefresh: forceTokenRefresh)
        request.setValue(token, forHTTPHeaderField: "Authorization")

        // Encode request body
        let graphQLRequest = GraphQLRequest(
            query: query,
            variables: variables,
            operationName: operationName
        )
        let requestBody = try encoder.encode(graphQLRequest)
        request.httpBody = requestBody

        // Log request
        logRequest(request: request, body: requestBody, operationName: operationName)

        // Perform request
        let (data, response) = try await session.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("[\(operationName ?? "unknown")] Invalid response type")
            throw APIClientError.unknown("Invalid response type")
        }

        // Log response
        logResponse(response: httpResponse, body: data, operationName: operationName)

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                logger.error("[\(operationName ?? "unknown")] Unauthorized (401)")
                throw APIClientError.unauthorized
            }
            logger.error("[\(operationName ?? "unknown")] HTTP error: \(httpResponse.statusCode)")
            throw APIClientError.http(httpResponse.statusCode)
        }

        // Decode response. If the full-shape decode fails, fall back to inspecting
        // just the `errors` array — this surfaces GraphQL-side errors even when the
        // returned `data` payload is null and would otherwise fail a strict decode.
        let graphQLResponse: GraphQLResponse<T>
        do {
            graphQLResponse = try decoder.decode(GraphQLResponse<T>.self, from: data)
        } catch {
            if let envelope = try? decoder.decode(ErrorsOnlyEnvelope.self, from: data),
               let errors = envelope.errors, !errors.isEmpty {
                logger.error("[\(operationName ?? "unknown")] GraphQL errors (data unparseable): \(errors.map { $0.message }.joined(separator: ", "))")
                if errors.contains(where: { $0.errorType == "401" || $0.errorType == "UNAUTHORIZED" }) {
                    throw APIClientError.unauthorized
                }
                throw APIClientError.graphQLErrors(errors)
            }
            logger.error("[\(operationName ?? "unknown")] Decoding error: \(error.localizedDescription)")
            throw APIClientError.decodingError(error.localizedDescription)
        }

        // Check for GraphQL errors
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            logger.error("[\(operationName ?? "unknown")] GraphQL errors: \(errors.map { $0.message }.joined(separator: ", "))")
            // Check for auth errors in GraphQL response
            if errors.contains(where: { $0.errorType == "401" || $0.errorType == "UNAUTHORIZED" }) {
                throw APIClientError.unauthorized
            }
            throw APIClientError.graphQLErrors(errors)
        }

        guard let data = graphQLResponse.data else {
            logger.error("[\(operationName ?? "unknown")] No data in response")
            throw APIClientError.noData
        }

        logger.info("[\(operationName ?? "unknown")] Request completed successfully")
        return data
    }

    private func logRequest(request: URLRequest, body: Data, operationName: String?) {
        let op = operationName ?? "unknown"

        logger.info("[\(op)] ========== REQUEST ==========")
        logger.info("[\(op)] URL: \(request.url?.absoluteString ?? "nil")")
        logger.info("[\(op)] Method: \(request.httpMethod ?? "nil")")

        // Log headers (mask the token)
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased() == "authorization" {
                    let maskedValue = value.prefix(20) + "..." + value.suffix(10)
                    logger.info("[\(op)] Header: \(key): \(maskedValue)")
                } else {
                    logger.info("[\(op)] Header: \(key): \(value)")
                }
            }
        }

        // Log body
        if let bodyString = String(data: body, encoding: .utf8) {
            // Pretty print JSON if possible
            if let jsonData = try? JSONSerialization.jsonObject(with: body),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                logger.info("[\(op)] Body:\n\(prettyString)")
            } else {
                logger.info("[\(op)] Body: \(bodyString)")
            }
        }
        logger.info("[\(op)] ==============================")
    }

    private func logResponse(response: HTTPURLResponse, body: Data, operationName: String?) {
        let op = operationName ?? "unknown"

        logger.info("[\(op)] ========== RESPONSE ==========")
        logger.info("[\(op)] Status Code: \(response.statusCode)")
        logger.info("[\(op)] URL: \(response.url?.absoluteString ?? "nil")")

        // Log headers
        for (key, value) in response.allHeaderFields {
            logger.info("[\(op)] Header: \(String(describing: key)): \(String(describing: value))")
        }

        // Log body
        if let bodyString = String(data: body, encoding: .utf8) {
            // Pretty print JSON if possible
            if let jsonData = try? JSONSerialization.jsonObject(with: body),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                logger.info("[\(op)] Body:\n\(prettyString)")
            } else {
                logger.info("[\(op)] Body: \(bodyString)")
            }
        } else {
            logger.info("[\(op)] Body: <unable to decode as UTF-8, \(body.count) bytes>")
        }
        logger.info("[\(op)] ===============================")
    }
}

// MARK: - Token Provider Protocol

public protocol TokenProviding: Sendable {
    func getToken(forceRefresh: Bool) async throws -> String
}

// MARK: - Errors-Only Envelope

/// Used to extract GraphQL errors from a response whose `data` payload doesn't
/// match the expected `T` shape (typically because the server returned `null`
/// data alongside a top-level error).
private struct ErrorsOnlyEnvelope: Decodable {
    let errors: [GraphQLError]?
}
