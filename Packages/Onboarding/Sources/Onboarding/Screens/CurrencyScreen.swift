import Core
import SwiftUI

struct CurrencyScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    private let continentOrder = [
        "North America", "South America", "Europe", "Middle East",
        "Asia", "Oceania", "Africa"
    ]
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 8)]

    private var grouped: [(continent: String, currencies: [Currency])] {
        let groups = Dictionary(grouping: Currency.allCurrencies) { $0.continent }
        return continentOrder.compactMap { continent in
            guard let items = groups[continent] else { return nil }
            return (continent, items.sorted { $0.id < $1.id })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(grouped, id: \.continent) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.continent)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(group.currencies) { currency in
                                MultiSelectButton(
                                    emoji: currency.emoji,
                                    label: currency.id,
                                    isSelected: viewModel.data.currency == currency.id
                                ) {
                                    viewModel.selectCurrency(currency.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
