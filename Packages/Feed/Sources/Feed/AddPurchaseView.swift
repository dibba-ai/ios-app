import ApiClient
import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "AddPurchaseView")

private let lastCategoryEntryKey = "addTransaction.lastCategoryEntry"

struct CategoryEntry: Hashable, Identifiable {
    let type: TransactionType
    let isIncome: Bool

    var id: String { "\(type.rawValue)_\(isIncome ? "in" : "out")" }
    var emoji: String { type.emoji }
    var name: String { type.displayName }
}

enum CategoryCatalog {
    static let spending: [CategoryEntry] = [
        .init(type: .posPurchase, isIncome: false),
        .init(type: .billPayment, isIncome: false),
        .init(type: .subscriptionPayment, isIncome: false),
        .init(type: .loanPayment, isIncome: false),
        .init(type: .atm, isIncome: false),
        .init(type: .transfer, isIncome: false),
    ]
    static let income: [CategoryEntry] = [
        .init(type: .transfer, isIncome: true),
    ]

    static func find(by id: String) -> CategoryEntry? {
        (spending + income).first { $0.id == id }
    }
}

struct AddPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.profileService) private var profileService

    let onCreated: (Servicing.Transaction) -> Void

    @State private var amountText: String = ""
    @State private var category: CategoryEntry = CategoryCatalog.spending[0]
    @State private var note: String = ""
    @State private var currency: String = "USD"
    @State private var showingCurrencyPicker = false
    @State private var showingCategoryPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var amountFocused: Bool

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        amountValue > 0 && !isSaving
    }

    private var amountTint: Color {
        category.isIncome ? .green : .primary
    }

    private var actionLabel: String {
        category.isIncome ? "Add Income" : "Add Purchase"
    }

    private var currencyDisplay: String {
        if let c = Currency.find(by: currency) {
            return "\(c.emoji) \(c.id)"
        }
        return currency
    }

    private var categoryDisplay: String {
        let suffix = category.isIncome ? " (Income)" : ""
        return "\(category.emoji) \(category.name)\(suffix)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                amountBlock
                Spacer(minLength: 0)
                controlsBlock
            }
            .navigationTitle(actionLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                NavigationStack {
                    CurrencySelectView(selected: currency) { newValue in
                        if let newValue { currency = newValue }
                        showingCurrencyPicker = false
                    }
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                NavigationStack {
                    CategorySelectView(selected: category) { entry in
                        category = entry
                        showingCategoryPicker = false
                    }
                }
            }
            .task { await onAppearSetup() }
            .onChange(of: category) { _, newValue in
                UserDefaults.standard.set(newValue.id, forKey: lastCategoryEntryKey)
            }
        }
    }

    // MARK: - Amount Block

    @ViewBuilder
    private var amountBlock: some View {
        TextField("0", text: $amountText)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .keyboardType(.decimalPad)
            .foregroundStyle(amountTint)
            .multilineTextAlignment(.center)
            .focused($amountFocused)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    // MARK: - Controls Block

    @ViewBuilder
    private var controlsBlock: some View {
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
            settingsRow(title: "Currency", value: currencyDisplay) {
                showingCurrencyPicker = true
            }
            Divider().padding(.leading, 16)
            settingsRow(title: "Category", value: categoryDisplay) {
                showingCategoryPicker = true
            }
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

    // MARK: - Primary Button

    @ViewBuilder
    private var primaryButton: some View {
        Button {
            Task { await save() }
        } label: {
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

    // MARK: - Lifecycle

    private func onAppearSetup() async {
        if let cached = await profileService.cachedProfile, let c = cached.currency, !c.isEmpty {
            currency = c
        }
        if let raw = UserDefaults.standard.string(forKey: lastCategoryEntryKey),
           let restored = CategoryCatalog.find(by: raw) {
            category = restored
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        amountFocused = true
    }

    // MARK: - Save

    private func save() async {
        guard amountValue > 0 else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedNote.isEmpty ? category.name : trimmedNote

        let isAtm = category.type == .atm
        let isTransfer = category.type == .transfer
        let purchaseLike: Set<TransactionType> = [.posPurchase, .billPayment, .subscriptionPayment, .loanPayment]
        let isPurchase = !category.isIncome && purchaseLike.contains(category.type)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let fullDate = formatter.string(from: Date())

        let input = CreateTransactionInput(
            name: displayName,
            amount: amountValue,
            currency: currency,
            isCredit: category.isIncome,
            isDebit: !category.isIncome,
            isAtm: isAtm,
            isPurchase: isPurchase,
            isTransfer: isTransfer,
            fullDate: fullDate
        )

        do {
            let created = try await transactionService.createTransaction(input)
            onCreated(created)
            dismiss()
        } catch {
            logger.error("Failed to create transaction: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Category Select View

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
