import ApiClient
import Core
import Servicing
import SwiftUI
import UI

struct PreferencesSection: View {
    let profile: Servicing.Profile
    let onUpdate: (UpdateProfileInput) async -> Void

    var body: some View {
        Section("Preferences") {
            goalsRow
            occupationRow
            housingRow
            transportRow
            ageRow
            currencyRow
        }
    }

    @ViewBuilder
    private var goalsRow: some View {
        let selected: Set<String> = Set(profile.goals)
        NavigationLink {
            MultiSelectView(
                title: "Main Goal",
                options: GoalOption.allCases,
                selected: selected,
                onUpdate: { newValues in
                    await onUpdate(UpdateProfileInput(goals: Array(newValues)))
                }
            )
        } label: {
            LabeledContent("Main Goal") {
                Text(formatSelected(profile.goals, from: GoalOption.self))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var occupationRow: some View {
        let selected: Set<String> = Set(profile.occupation)
        NavigationLink {
            MultiSelectView(
                title: "Occupation",
                options: OccupationOption.allCases,
                selected: selected,
                onUpdate: { newValues in
                    await onUpdate(UpdateProfileInput(occupation: Array(newValues)))
                }
            )
        } label: {
            LabeledContent("Occupation") {
                Text(formatSelected(profile.occupation, from: OccupationOption.self))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var housingRow: some View {
        let selected: Set<String> = Set(profile.housing)
        NavigationLink {
            MultiSelectView(
                title: "Housing",
                options: HousingOption.allCases,
                selected: selected,
                onUpdate: { newValues in
                    await onUpdate(UpdateProfileInput(housing: Array(newValues)))
                }
            )
        } label: {
            LabeledContent("Housing") {
                Text(formatSelected(profile.housing, from: HousingOption.self))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var transportRow: some View {
        let selected: Set<String> = Set(profile.transport)
        NavigationLink {
            MultiSelectView(
                title: "Commute",
                options: TransportOption.allCases,
                selected: selected,
                onUpdate: { newValues in
                    await onUpdate(UpdateProfileInput(transport: Array(newValues)))
                }
            )
        } label: {
            LabeledContent("Commute") {
                Text(formatSelected(profile.transport, from: TransportOption.self))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var ageRow: some View {
        NavigationLink {
            SingleSelectView(
                title: "Age",
                options: AgeOption.allCases,
                selected: profile.age,
                onUpdate: { newValue in
                    await onUpdate(UpdateProfileInput(age: newValue))
                }
            )
        } label: {
            LabeledContent("Age") {
                if let age = profile.age, let option = AgeOption(rawValue: age) {
                    Text(option.label)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not Set")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var currencyRow: some View {
        NavigationLink {
            CurrencySelectView(
                selected: profile.currency,
                onUpdate: { newValue in
                    await onUpdate(UpdateProfileInput(currency: newValue))
                }
            )
        } label: {
            LabeledContent("Currency") {
                if let currency = Servicing.Currency.find(by: profile.currency) {
                    Text("\(currency.emoji) \(currency.id)")
                        .foregroundStyle(.secondary)
                } else if let currencyCode = profile.currency {
                    Text(currencyCode)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not Set")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func formatSelected<T: RawRepresentable & CaseIterable>(_ selected: [String], from type: T.Type) -> String where T.RawValue == String, T: Identifiable {
        guard !selected.isEmpty else { return "None" }
        let items = selected.compactMap { id -> (emoji: String, label: String)? in
            guard let option = T.allCases.first(where: { $0.rawValue == id }) else { return nil }
            if let goal = option as? GoalOption { return (goal.emoji, goal.label) }
            if let occupation = option as? OccupationOption { return (occupation.emoji, occupation.label) }
            if let housing = option as? HousingOption { return (housing.emoji, housing.label) }
            if let transport = option as? TransportOption { return (transport.emoji, transport.label) }
            return nil
        }
        if items.count == 1 { return "\(items[0].emoji) \(items[0].label)" }
        return items.map { $0.emoji }.joined(separator: " ")
    }
}
