import Analytics
import ApiClient
import AppIntents

public struct LogPurchaseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Purchase"
    public static let description = IntentDescription("Record a purchase by voice.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Amount", controlStyle: .field)
    public var amount: Double

    @Parameter(title: "Currency")
    public var currencyTerm: String?

    @Parameter(title: "Description", requestValueDialog: "What's it for?")
    public var note: String

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Log purchase of \(\.$amount) \(\.$currencyTerm) for \(\.$note)")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Analytics.bootstrap()
        let analytics = Services.analytics
        let intentName = "log_purchase"
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
        let name = note.nilIfEmpty ?? "Purchase"

        let input = CreateTransactionInput(
            name: name,
            amount: amount,
            currency: currency,
            isCredit: false,
            isDebit: true,
            isAtm: false,
            isPurchase: true,
            isTransfer: false,
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

        return .result(dialog: "Logged \(amount, format: .number) \(currency) for \(name).")
    }
}
