import Analytics
import ApiClient
import AppIntents

public struct LogTransferIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Transfer"
    public static let description = IntentDescription("Record a transfer by voice.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Amount", controlStyle: .field)
    public var amount: Double

    @Parameter(title: "Direction", default: .outgoing)
    public var direction: TransferDirection

    @Parameter(title: "Currency")
    public var currencyTerm: String?

    @Parameter(title: "Description", requestValueDialog: "Who's the transfer for?")
    public var note: String

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$direction) transfer of \(\.$amount) \(\.$currencyTerm) for \(\.$note)")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Analytics.bootstrap()
        let analytics = Services.analytics
        let intentName = "log_transfer"
        let isIncoming = direction == .incoming
        let directionWord: String = isIncoming ? "incoming" : "outgoing"
        analytics.capture(.intentInvoked, properties: [
            "intent": .string(intentName),
            "direction": .string(directionWord)
        ])

        guard amount > 0 else {
            analytics.capture(.intentFailed, properties: [
                "intent": .string(intentName),
                "direction": .string(directionWord),
                "error": .string("invalid_amount")
            ])
            analytics.flush()
            throw IntentError.invalidAmount
        }

        let currency = await CurrencyResolver.resolve(term: currencyTerm)
        let name = note.nilIfEmpty ?? "Transfer"

        let input = CreateTransactionInput(
            name: name,
            amount: amount,
            currency: currency,
            isCredit: isIncoming,
            isDebit: !isIncoming,
            isAtm: false,
            isPurchase: false,
            isTransfer: true,
            fullDate: IntentDateFormatter.todayISO()
        )

        do {
            _ = try await Services.transaction.createTransaction(input)
            analytics.capture(.intentSucceeded, properties: [
                "intent": .string(intentName),
                "direction": .string(directionWord),
                "amount": .double(amount),
                "currency": .string(currency)
            ])
            analytics.flush()
        } catch {
            analytics.capture(.intentFailed, properties: [
                "intent": .string(intentName),
                "direction": .string(directionWord),
                "error": .string(String(describing: error))
            ])
            analytics.flush()
            throw IntentError.from(error)
        }

        return .result(dialog: "Logged \(directionWord) transfer of \(amount, format: .number) \(currency).")
    }
}
