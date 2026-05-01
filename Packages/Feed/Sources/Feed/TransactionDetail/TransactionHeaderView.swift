import Servicing
import SwiftUI

struct TransactionHeaderView: View {
    let transaction: Servicing.Transaction

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(transaction.success ? (transaction.isCredit ? Color.green.opacity(0.15) : Color(.systemGray5)) : Color.red.opacity(0.15))
                    .frame(width: 72, height: 72)

                if transaction.success {
                    Text(iconEmoji)
                        .font(.system(size: 32))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.red)
                }
            }

            Text(transaction.name.isEmpty ? transaction.transactionType.displayName : transaction.name)
                .font(.title2.bold())
                .strikethrough(!transaction.success, color: .red)
                .multilineTextAlignment(.center)

            Text(amountText)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(transaction.success ? (transaction.isCredit ? .green : .primary) : .red)
                .strikethrough(!transaction.success, color: .red)

            HStack(spacing: 6) {
                Image(systemName: transaction.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(transaction.success ? .green : .red)
                Text(transaction.success ? "Successful" : "Failed")
                    .foregroundStyle(transaction.success ? .green : .red)
            }
            .font(.subheadline.weight(.medium))

            if let errorMessage = transaction.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var iconEmoji: String {
        if transaction.isAtm { return "🏧" }
        if transaction.isTransfer { return "↔️" }
        if transaction.isPurchase {
            return merchantCategoryEmojis[transaction.merchantCategory] ?? "🛒"
        }
        return transaction.transactionType.emoji
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        let absAmount = abs(transaction.amount)
        let formatted = formatter.string(from: NSNumber(value: absAmount)) ?? "\(absAmount)"
        return transaction.isCredit ? "+\(formatted)" : "-\(formatted)"
    }
}
