import Servicing
import SwiftUI

struct TransactionAccountSection: View {
    let transaction: Servicing.Transaction

    var body: some View {
        let hasCard = !transaction.cardNumber.isEmpty
        let hasAccount = !transaction.accountNumber.isEmpty

        if hasCard || hasAccount {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(icon: "creditcard.fill", title: "Account")

                if hasCard {
                    LabeledContent("Card", value: transaction.cardNumber)
                }

                if hasAccount {
                    LabeledContent("Account", value: transaction.accountNumber)
                }

                LabeledContent("Currency", value: transaction.currency)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
