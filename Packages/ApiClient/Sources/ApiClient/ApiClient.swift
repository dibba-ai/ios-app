import Foundation
import Dependencies
import Auth

// MARK: - API Configuration

public enum APIConfiguration {
    public static let apiServiceURL = URL(string: "https://api-service.dibba.ai/graphql")!
    public static let identityServiceURL = URL(string: "https://id.dibba.ai/graphql")!
    public static let billingServiceURL = URL(string: "https://billing-service.dibba.ai/graphql")!
}

// MARK: - API Client Protocol

public protocol APIClienting: Sendable {
    // Profile
    func getProfile() async throws -> ProfileDTO
    func updateProfile(input: UpdateProfileInput) async throws -> ProfileDTO

    // Transactions
    func listTransactions(nextToken: String?, perPage: Int) async throws -> ListTransactionsData
    func createTransaction(input: CreateTransactionInput) async throws -> TransactionDTO
    func updateTransaction(id: String, input: UpdateTransactionInput) async throws -> TransactionDTO
    func deleteTransaction(id: String) async throws -> Bool

    // Targets
    func listTargets() async throws -> [TargetDTO]
    func createTarget(input: CreateTargetInput) async throws -> TargetDTO
    func updateTarget(id: String, input: UpdateTargetInput) async throws -> TargetDTO

    // Reports
    func listReports(ids: [String]) async throws -> [ReportDTO]

    // API Keys
    func listApiKeys() async throws -> [ApiKeyDTO]
    func createApiKey(input: CreateApiKeyInput) async throws -> ApiKeyDTO
}

// MARK: - API Client Implementation

public final class APIClient: APIClienting, @unchecked Sendable {
    private let apiClient: GraphQLClient
    private let identityClient: GraphQLClient
    private let billingClient: GraphQLClient

    public init(tokenProvider: TokenProviding) {
        self.apiClient = GraphQLClient(
            baseURL: APIConfiguration.apiServiceURL,
            tokenProvider: tokenProvider
        )
        self.identityClient = GraphQLClient(
            baseURL: APIConfiguration.identityServiceURL,
            tokenProvider: tokenProvider
        )
        self.billingClient = GraphQLClient(
            baseURL: APIConfiguration.billingServiceURL,
            tokenProvider: tokenProvider
        )
    }

    // MARK: - Profile (API Service)

    public func getProfile() async throws -> ProfileDTO {
        let response: ProfileResponse = try await apiClient.execute(
            query: ProfileQueries.getProfile,
            variables: EmptyVariables(),
            operationName: "profile"
        )
        return response.profile
    }

    public func updateProfile(input: UpdateProfileInput) async throws -> ProfileDTO {
        let response: UpdateProfileResponse = try await apiClient.execute(
            query: ProfileQueries.updateProfile,
            variables: UpdateProfileVariables(input: input),
            operationName: "updateProfile"
        )
        return response.updateProfile
    }

    // MARK: - Transactions (API Service)

    public func listTransactions(nextToken: String? = nil, perPage: Int = 100) async throws -> ListTransactionsData {
        let response: ListTransactionsResponse = try await apiClient.execute(
            query: TransactionQueries.listTransactions,
            variables: ListTransactionsVariables(nextToken: nextToken, perPage: perPage),
            operationName: "listTransactions"
        )
        return response.listTransactions
    }

    public func createTransaction(input: CreateTransactionInput) async throws -> TransactionDTO {
        let response: CreateTransactionResponse = try await apiClient.execute(
            query: TransactionQueries.createTransaction,
            variables: CreateTransactionVariables(input: input),
            operationName: "createTransaction"
        )
        guard let dto = response.createTransaction else {
            throw APIClientError.noData
        }
        return dto
    }

    public func updateTransaction(id: String, input: UpdateTransactionInput) async throws -> TransactionDTO {
        let response: UpdateTransactionResponse = try await apiClient.execute(
            query: TransactionQueries.updateTransaction,
            variables: UpdateTransactionVariables(id: id, input: input),
            operationName: "updateTransaction"
        )
        return response.updateTransaction
    }

    public func deleteTransaction(id: String) async throws -> Bool {
        let response: DeleteTransactionResponse = try await apiClient.execute(
            query: TransactionQueries.deleteTransaction,
            variables: DeleteTransactionVariables(id: id),
            operationName: "deleteTransaction"
        )
        return response.deleteTransaction.success
    }

    // MARK: - Targets (API Service)

    public func listTargets() async throws -> [TargetDTO] {
        let response: ListTargetsResponse = try await apiClient.execute(
            query: TargetQueries.listTargets,
            variables: EmptyVariables(),
            operationName: "listTargets"
        )
        return response.listTargets
    }

    public func createTarget(input: CreateTargetInput) async throws -> TargetDTO {
        let response: CreateTargetResponse = try await apiClient.execute(
            query: TargetQueries.createTarget,
            variables: CreateTargetVariables(input: input),
            operationName: "createTarget"
        )
        return response.createTarget
    }

    public func updateTarget(id: String, input: UpdateTargetInput) async throws -> TargetDTO {
        let response: UpdateTargetResponse = try await apiClient.execute(
            query: TargetQueries.updateTarget,
            variables: UpdateTargetVariables(id: id, input: input),
            operationName: "updateTarget"
        )
        return response.updateTarget
    }

    // MARK: - API Keys (API Service)

    public func listApiKeys() async throws -> [ApiKeyDTO] {
        let response: ListApiKeysResponse = try await apiClient.execute(
            query: ApiKeyQueries.listApiKeys,
            variables: EmptyVariables(),
            operationName: "listApiKeys"
        )
        return response.listApiKeys
    }

    public func createApiKey(input: CreateApiKeyInput) async throws -> ApiKeyDTO {
        let response: CreateApiKeyResponse = try await apiClient.execute(
            query: ApiKeyQueries.createApiKey,
            variables: CreateApiKeyVariables(input: input),
            operationName: "createApiKey"
        )
        return response.createApiKey
    }

    // MARK: - Reports (API Service)

    public func listReports(ids: [String]) async throws -> [ReportDTO] {
        let response: ListReportsResponse = try await apiClient.execute(
            query: ReportQueries.listReports,
            variables: ListReportsVariables(ids: ids),
            operationName: "listReports"
        )
        return response.listReports
    }
}

// MARK: - Auth Token Provider Adapter

public final class AuthTokenProvider: TokenProviding, @unchecked Sendable {
    @Dependency(\.authService) private var authService

    public init() {}

    public func getToken(forceRefresh: Bool) async throws -> String {
        if forceRefresh {
            // Force a re-check of authentication status
            await authService.checkAuthenticationStatus()
        }

        guard let user = await authService.currentUser,
              let token = user.accessToken else {
            throw APIClientError.unauthorized
        }

        return token
    }
}

// MARK: - Dependency Key

extension APIClient: DependencyKey {
    public static let liveValue: any APIClienting = APIClient(
        tokenProvider: AuthTokenProvider()
    )

    public static let testValue: any APIClienting = MockAPIClient()
}

public extension DependencyValues {
    var apiClient: any APIClienting {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}

// MARK: - Mock API Client

public final class MockAPIClient: APIClienting, @unchecked Sendable {
    public init() {}

    public func getProfile() async throws -> ProfileDTO {
        ProfileDTO(
            goals: ["save_money"],
            occupation: nil,
            housing: nil,
            transport: nil,
            currency: "USD",
            age: nil,
            notifyDailyReport: false,
            notifyWeeklyReport: true,
            notifyMonthlyReport: true,
            notifyAnnualReport: true,
            notifyNewRecommendation: true,
            favoriteRealtimeVoice: nil,
            achievements: [],
            createdAt: Date(),
            email: "test@example.com",
            name: "Test User",
            firstName: "Test",
            lastName: "User",
            picture: nil,
            timezone: "America/New_York",
            plan: "DIBBA_AI_FREE",
            planStartsAt: nil,
            planExpiresAt: nil
        )
    }

    public func updateProfile(input: UpdateProfileInput) async throws -> ProfileDTO {
        try await getProfile()
    }

    public func listTransactions(nextToken: String?, perPage: Int) async throws -> ListTransactionsData {
        ListTransactionsData(list: [], nextToken: nil)
    }

    public func createTransaction(input: CreateTransactionInput) async throws -> TransactionDTO {
        TransactionDTO(
            id: UUID().uuidString,
            accountNumber: nil,
            cardNumber: nil,
            name: input.name,
            merchantCategory: nil,
            amount: input.amount,
            currency: input.currency,
            success: true,
            isCredit: input.amount > 0,
            isDebit: input.amount < 0,
            isAtm: false,
            isPurchase: true,
            isTransfer: false,
            fullDate: nil,
            orgType: nil,
            orgName: nil,
            transactionType: "pos_purchase",
            errorMessage: nil,
            input: nil,
            metadata: nil,
            createdAt: Date()
        )
    }

    public func updateTransaction(id: String, input: UpdateTransactionInput) async throws -> TransactionDTO {
        TransactionDTO(
            id: id,
            accountNumber: nil,
            cardNumber: nil,
            name: input.name ?? "Updated",
            merchantCategory: nil,
            amount: input.amount ?? 0,
            currency: input.currency ?? "USD",
            success: true,
            isCredit: false,
            isDebit: false,
            isAtm: false,
            isPurchase: true,
            isTransfer: false,
            fullDate: nil,
            orgType: nil,
            orgName: nil,
            transactionType: "pos_purchase",
            errorMessage: nil,
            input: nil,
            metadata: nil,
            createdAt: Date()
        )
    }

    public func deleteTransaction(id: String) async throws -> Bool {
        true
    }

    public func listTargets() async throws -> [TargetDTO] {
        []
    }

    public func createTarget(input: CreateTargetInput) async throws -> TargetDTO {
        TargetDTO(
            id: UUID().uuidString,
            name: input.name,
            emoji: input.emoji,
            strategy: input.strategy,
            currency: input.currency,
            amountSaved: 0,
            amountTarget: input.amountTarget,
            expectedStartAt: input.expectedStartAt,
            expectedEndAt: input.expectedEndAt,
            remindWeekly: input.remindWeekly,
            remindMonthly: input.remindMonthly,
            completed: false,
            archived: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    public func updateTarget(id: String, input: UpdateTargetInput) async throws -> TargetDTO {
        TargetDTO(
            id: id,
            name: input.name ?? "Updated",
            emoji: input.emoji,
            strategy: input.strategy,
            currency: input.currency,
            amountSaved: input.amountSaved,
            amountTarget: input.amountTarget,
            expectedStartAt: input.expectedStartAt,
            expectedEndAt: input.expectedEndAt,
            remindWeekly: input.remindWeekly,
            remindMonthly: input.remindMonthly,
            completed: input.completed,
            archived: input.archived,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    public func listApiKeys() async throws -> [ApiKeyDTO] {
        []
    }

    public func createApiKey(input: CreateApiKeyInput) async throws -> ApiKeyDTO {
        ApiKeyDTO(
            id: UUID().uuidString,
            name: input.name,
            active: true,
            createdAt: Int(Date().timeIntervalSince1970),
            createdAtIso: ISO8601DateFormatter().string(from: Date())
        )
    }

    public func listReports(ids: [String]) async throws -> [ReportDTO] {
        []
    }
}
