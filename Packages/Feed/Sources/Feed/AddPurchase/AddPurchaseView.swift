import Analytics
import ApiClient
import Core
import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "AddPurchaseView")

private let lastCategoryEntryKey = "addTransaction.lastCategoryEntry"

struct AddPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.profileService) private var profileService
    @Dependency(\.analytics) private var analytics

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

    private var canSave: Bool { amountValue > 0 && !isSaving }
    private var amountTint: Color { category.isIncome ? .green : .primary }
    private var actionLabel: String { category.isIncome ? "Add Income" : "Add Purchase" }

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
                amountField
                Spacer(minLength: 0)
                AddPurchaseControlsView(
                    currencyDisplay: currencyDisplay,
                    categoryDisplay: categoryDisplay,
                    note: $note,
                    errorMessage: errorMessage,
                    isSaving: isSaving,
                    canSave: canSave,
                    actionLabel: actionLabel,
                    onCurrencyTap: { showingCurrencyPicker = true },
                    onCategoryTap: { showingCategoryPicker = true },
                    onSave: { Task { await save() } }
                )
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
            .onAppear { analytics.capture(.addTransactionModalOpened) }
            .onDisappear { analytics.capture(.addTransactionModalClosed) }
            .onChange(of: category) { _, newValue in
                UserDefaults.standard.set(newValue.id, forKey: lastCategoryEntryKey)
            }
        }
    }

    @ViewBuilder
    private var amountField: some View {
        TextField("0", text: $amountText)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .keyboardType(.decimalPad)
            .foregroundStyle(amountTint)
            .multilineTextAlignment(.center)
            .focused($amountFocused)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

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
            analytics.capture(.manualTransactionAdded, properties: [
                "source": .string("modal"),
                "amount": .double(amountValue),
                "currency": .string(currency),
                "is_income": .bool(category.isIncome)
            ])
            onCreated(created)
            dismiss()
        } catch {
            logger.error("Failed to create transaction: \(error.localizedDescription)")
            analytics.capture(.manualTransactionFailed, properties: [
                "source": .string("modal"),
                "error": .string(error.localizedDescription)
            ])
            errorMessage = error.localizedDescription
        }
    }
}
