import SwiftUI

// MARK: - Currency Select View

public struct CurrencySelectView: View {
    let selected: String?
    let onUpdate: (String?) async -> Void

    @State private var localSelected: String?
    @State private var searchText = ""
    @State private var isUpdating = false

    public init(selected: String?, onUpdate: @escaping (String?) async -> Void) {
        self.selected = selected
        self.onUpdate = onUpdate
        self._localSelected = State(initialValue: selected)
    }

    private var groupedCurrencies: [String: [Currency]] {
        Dictionary(grouping: filteredCurrencies) { $0.continent }
    }

    private var sortedContinents: [String] {
        let order = ["North America", "South America", "Europe", "Middle East", "Asia", "Oceania", "Africa"]
        return groupedCurrencies.keys.sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = order.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return Currency.allCurrencies
        }
        return Currency.allCurrencies.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.continent.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        List {
            ForEach(sortedContinents, id: \.self) { continent in
                Section(continent) {
                    ForEach(groupedCurrencies[continent] ?? []) { currency in
                        let isSelected = localSelected == currency.id
                        Button {
                            localSelected = currency.id
                            Task {
                                isUpdating = true
                                await onUpdate(currency.id)
                                isUpdating = false
                            }
                        } label: {
                            HStack {
                                Text(currency.emoji)
                                Text(currency.label)

                                Spacer()

                                Text(currency.id)
                                    .foregroundStyle(.secondary)

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .disabled(isUpdating)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Currency")
        .searchable(text: $searchText, prompt: "Search currencies")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isUpdating {
                    ProgressView()
                }
            }
        }
        .onChange(of: selected) { _, newValue in
            localSelected = newValue
        }
    }
}
