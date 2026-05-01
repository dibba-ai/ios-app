import Servicing
import SwiftUI

struct TransactionInputSection: View {
    let input: Servicing.TransactionInput

    var body: some View {
        let hasFields = input.from != nil || input.merchant != nil || input.card != nil || input.amount != nil

        if hasFields {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(icon: "square.and.pencil", title: "Input")

                if let from = input.from, !from.isEmpty {
                    LabeledContent("From", value: from)
                }
                if let merchant = input.merchant, !merchant.isEmpty {
                    LabeledContent("Merchant", value: merchant)
                }
                if let card = input.card, !card.isEmpty {
                    LabeledContent("Card", value: card)
                }
                if let amount = input.amount, !amount.isEmpty {
                    LabeledContent("Amount", value: amount)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
