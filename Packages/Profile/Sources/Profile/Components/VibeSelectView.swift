import Core
import SwiftUI

struct VibeSelectView: View {
    let selected: String?
    let onUpdate: (String?) async -> Void

    @State private var localSelected: String?
    @State private var isUpdating = false

    init(selected: String?, onUpdate: @escaping (String?) async -> Void) {
        self.selected = selected
        self.onUpdate = onUpdate
        self._localSelected = State(initialValue: selected)
    }

    var body: some View {
        List {
            ForEach(VibeOption.allCases) { option in
                vibeRow(option)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Vibe")
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

    @ViewBuilder
    private func vibeRow(_ option: VibeOption) -> some View {
        let isSelected = localSelected == option.rawValue
        Button {
            localSelected = option.rawValue
            Task {
                isUpdating = true
                await onUpdate(option.rawValue)
                isUpdating = false
            }
        } label: {
            HStack(spacing: 12) {
                Text(option.emoji)
                Text(option.label)
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
