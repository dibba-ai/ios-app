import Analytics
import ApiClient
import AppIntents

public struct LogIncomeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Income"
    public static let description = IntentDescription("Record income by voice.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Amount", controlStyle: .field)
    public var amount: Double

    @Parameter(title: "Currency")
    public var currencyTerm: String?

    @Parameter(title: "Source", requestValueDialog: "Where did it come from?")
    public var note: String

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Log income of \(\.$amount) \(\.$currencyTerm) from \(\.$note)")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Analytics.bootstrap()
        let analytics = Services.analytics
        let intentName = "log_income"
        analytics.capture(.intentInvoked, properties: ["intent": .string(intentName)])

        guard amount > 0 else {
            analytics.capture(.intentFailed, properties: [
                "intent": .string(intentName),
                "error": .string("invalid_amount")
            ])
            analytics.flush()
            throw IntentError.invalidAmount
        }

        let currency = await CurrencyResolver.resolve(term: currencyTerm)
        let name = note.nilIfEmpty ?? "Income"

        let input = CreateTransactionInput(
            name: name,
            amount: amount,
            currency: currency,
            isCredit: true,
            isDebit: false,
            isAtm: false,
            isPurchase: false,
            isTransfer: true,
            fullDate: IntentDateFormatter.todayISO()
        )

        do {
            _ = try await Services.transaction.createTransaction(input)
            analytics.capture(.intentSucceeded, properties: [
                "intent": .string(intentName),
                "amount": .double(amount),
                "currency": .string(currency)
            ])
            analytics.flush()
        } catch {
            analytics.capture(.intentFailed, properties: [
                "intent": .string(intentName),
                "error": .string(String(describing: error))
            ])
            analytics.flush()
            throw IntentError.from(error)
        }

        return .result(dialog: "Logged \(amount, format: .number) \(currency) from \(name).")
    }
}
