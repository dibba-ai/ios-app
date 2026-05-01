import Servicing
import SwiftUI

struct TransactionDetailsSection: View {
    let transaction: Servicing.Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "info.circle.fill", title: "Details")

            LabeledContent("Type", value: transaction.transactionType.displayName)

            if transaction.isPurchase, !transaction.merchantCategory.isEmpty {
                LabeledContent("Category", value: transaction.merchantCategory)
            }

            LabeledContent("Date", value: transaction.fullDate)
            LabeledContent("Time", value: formattedTime)

            if !transaction.orgName.isEmpty {
                LabeledContent {
                    VStack(alignment: .trailing) {
                        Text(transaction.orgName)
                        if !transaction.orgType.isEmpty {
                            Text(transaction.orgType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Text("Organization")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: transaction.createdAt)
    }
}
