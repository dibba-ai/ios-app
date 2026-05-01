import SwiftUI

struct AddPurchaseControlsView: View {
    let currencyDisplay: String
    let categoryDisplay: String
    @Binding var note: String
    let errorMessage: String?
    let isSaving: Bool
    let canSave: Bool
    let actionLabel: String
    let onCurrencyTap: () -> Void
    let onCategoryTap: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            settingsRows
                .padding(.horizontal, 20)
            noteField
                .padding(.horizontal, 20)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }
            primaryButton
        }
    }

    @ViewBuilder
    private var settingsRows: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Currency", value: currencyDisplay, action: onCurrencyTap)
            Divider().padding(.leading, 16)
            settingsRow(title: "Category", value: categoryDisplay, action: onCategoryTap)
        }
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func settingsRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var noteField: some View {
        TextField("Add note (optional)", text: $note, axis: .vertical)
            .lineLimit(1...3)
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var primaryButton: some View {
        Button(action: onSave) {
            ZStack {
                if isSaving {
                    ProgressView()
                } else {
                    Text(actionLabel)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                canSave ? Color.accentColor : Color.gray.opacity(0.25),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(canSave ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
