import Servicing
import SwiftUI

// MARK: - Merchant Category Emoji Mapping

let merchantCategoryEmojis: [String: String] = [
    "grocery_stores": "🛒",
    "restaurants": "🍽️",
    "clothing": "👕",
    "electronics": "📱",
    "gas_stations": "⛽",
    "department_stores": "🏬",
    "pharmacies": "💊",
    "books": "📚",
    "coffee_shops": "☕",
    "fast_food": "🍔",
    "jewelry_stores": "💍",
    "sporting_goods": "🏅",
    "automotive": "🚗",
    "beauty_salons": "💇",
    "furniture_stores": "🛋️",
    "office_supplies": "📎",
    "pet_stores": "🐾",
    "hardware_stores": "🔧",
    "toys": "🧸",
    "florists": "💐",
    "music_stores": "🎵",
    "health_and_wellness": "🏥",
    "liquor_stores": "🍷",
    "convenience_stores": "🏪",
    "games": "🎮",
    "transport": "🚌",
    "airline": "✈️",
    "hotel": "🏨",
    "travel": "🧳",
    "other": "📦",
]

// MARK: - Transaction Row

public struct TransactionRow: View {
    public let transaction: Servicing.Transaction

    public init(transaction: Servicing.Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(transaction.success ? iconBackground : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)

                if transaction.success {
                    Text(iconEmoji)
                        .font(.title3)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name.isEmpty ? transaction.transactionType.displayName : transaction.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(!transaction.success, color: .red)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(amountText)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.success ? amountColor : .red)
                .strikethrough(!transaction.success, color: .red)
        }
        .padding(.vertical, 4)
    }

    private var iconEmoji: String {
        if transaction.isAtm {
            return "🏧"
        }
        if transaction.isTransfer {
            return "↔️"
        }
        if transaction.isPurchase {
            return merchantCategoryEmojis[transaction.merchantCategory] ?? "🛒"
        }
        return transaction.transactionType.emoji
    }

    private var iconBackground: Color {
        if transaction.isCredit {
            return Color.green.opacity(0.15)
        }
        return Color(.systemGray5)
    }

    private var subtitleText: String {
        var parts: [String] = []
        if !transaction.orgName.isEmpty {
            parts.append(transaction.orgName)
        }
        let card = transaction.cardNumber.isEmpty ? transaction.accountNumber : transaction.cardNumber
        if !card.isEmpty {
            parts.append(card)
        }
        if transaction.isPurchase, !transaction.merchantCategory.isEmpty {
            parts.append(transaction.merchantCategory)
        }
        if transaction.isAtm {
            parts.append("ATM")
        }
        if transaction.isTransfer {
            parts.append("Transfer")
        }
        return parts.joined(separator: " · ")
    }

    private var amountColor: Color {
        transaction.isCredit ? .green : .primary
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        let absAmount = abs(transaction.amount)
        let formatted = formatter.string(from: NSNumber(value: absAmount)) ?? "\(absAmount)"
        if transaction.isCredit {
            return "\(formatted)+"
        }
        return "\(formatted)-"
    }
}
