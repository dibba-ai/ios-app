import SwiftUI

struct CategorySelectView: View {
    let selected: CategoryEntry
    let onSelect: (CategoryEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Spending") {
                ForEach(CategoryCatalog.spending) { entry in
                    row(entry)
                }
            }
            Section("Income") {
                ForEach(CategoryCatalog.income) { entry in
                    row(entry)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: CategoryEntry) -> some View {
        Button {
            onSelect(entry)
        } label: {
            HStack {
                Text(entry.emoji)
                Text(entry.name)
                Spacer()
                if selected == entry {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
