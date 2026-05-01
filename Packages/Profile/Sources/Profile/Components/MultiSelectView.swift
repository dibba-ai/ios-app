import Core
import SwiftUI

struct MultiSelectView<Option: Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let options: [Option]
    let selected: Set<String>
    let onUpdate: (Set<String>) async -> Void

    @State private var localSelected: Set<String>
    @State private var isUpdating = false

    init(title: String, options: [Option], selected: Set<String>, onUpdate: @escaping (Set<String>) async -> Void) {
        self.title = title
        self.options = options
        self.selected = selected
        self.onUpdate = onUpdate
        self._localSelected = State(initialValue: selected)
    }

    var body: some View {
        List {
            ForEach(options) { option in
                let isSelected = localSelected.contains(option.rawValue)
                Button {
                    if isSelected {
                        localSelected.remove(option.rawValue)
                    } else {
                        localSelected.insert(option.rawValue)
                    }
                    Task {
                        isUpdating = true
                        await onUpdate(localSelected)
                        isUpdating = false
                    }
                } label: {
                    HStack {
                        if let goal = option as? GoalOption {
                            Text(goal.emoji)
                            Text(goal.label)
                        } else if let occupation = option as? OccupationOption {
                            Text(occupation.emoji)
                            Text(occupation.label)
                        } else if let housing = option as? HousingOption {
                            Text(housing.emoji)
                            Text(housing.label)
                        } else if let transport = option as? TransportOption {
                            Text(transport.emoji)
                            Text(transport.label)
                        }

                        Spacer()

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
        .listStyle(.insetGrouped)
        .navigationTitle(title)
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
