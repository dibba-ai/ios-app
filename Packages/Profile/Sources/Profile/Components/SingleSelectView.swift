import Core
import SwiftUI

struct SingleSelectView<Option: Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let options: [Option]
    let selected: String?
    let onUpdate: (String?) async -> Void

    @State private var localSelected: String?
    @State private var isUpdating = false
    @Environment(\.dismiss) private var dismiss

    init(title: String, options: [Option], selected: String?, onUpdate: @escaping (String?) async -> Void) {
        self.title = title
        self.options = options
        self.selected = selected
        self.onUpdate = onUpdate
        self._localSelected = State(initialValue: selected)
    }

    var body: some View {
        List {
            ForEach(options) { option in
                let isSelected = localSelected == option.rawValue
                Button {
                    localSelected = option.rawValue
                    Task {
                        isUpdating = true
                        await onUpdate(option.rawValue)
                        isUpdating = false
                    }
                } label: {
                    HStack {
                        if let age = option as? AgeOption {
                            Text(age.label)
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
