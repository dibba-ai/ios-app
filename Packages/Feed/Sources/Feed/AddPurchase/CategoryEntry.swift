import Servicing

struct CategoryEntry: Hashable, Identifiable {
    let type: TransactionType
    let isIncome: Bool

    var id: String { "\(type.rawValue)_\(isIncome ? "in" : "out")" }
    var emoji: String { type.emoji }
    var name: String { type.displayName }
}

enum CategoryCatalog {
    static let spending: [CategoryEntry] = [
        .init(type: .posPurchase, isIncome: false),
        .init(type: .billPayment, isIncome: false),
        .init(type: .subscriptionPayment, isIncome: false),
        .init(type: .loanPayment, isIncome: false),
        .init(type: .atm, isIncome: false),
        .init(type: .transfer, isIncome: false),
    ]
    static let income: [CategoryEntry] = [
        .init(type: .transfer, isIncome: true),
    ]

    static func find(by id: String) -> CategoryEntry? {
        (spending + income).first { $0.id == id }
    }
}
