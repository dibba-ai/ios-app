import Servicing
import SwiftUI

struct TransactionDetailView: View {
    let transaction: Servicing.Transaction
    var isScrollDisabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TransactionHeaderView(transaction: transaction)

                if let location = transaction.input?.location, !location.isEmpty {
                    LocationMapView(address: location)
                }

                if let text = transaction.input?.text, !text.isEmpty {
                    TransactionMessageBubble(text: text)
                }

                TransactionDetailsSection(transaction: transaction)
                TransactionAccountSection(transaction: transaction)

                if let input = transaction.input {
                    TransactionInputSection(input: input)
                }

                if let metadata = transaction.metadata {
                    TransactionMetadataSection(metadata: metadata)
                }
            }
            .padding()
        }
        .scrollDisabled(isScrollDisabled)
    }
}
