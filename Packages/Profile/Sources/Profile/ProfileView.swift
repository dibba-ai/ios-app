import ApiClient
import Auth
import Dependencies
import os.log
import Servicing
import SwiftUI
import UI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "ProfileView")

// MARK: - Preference Options

enum GoalOption: String, CaseIterable, Identifiable {
    case retire, business, kids, travel, house, car, emergency, save

    var id: String { rawValue }

    var label: String {
        switch self {
        case .retire: return "Retire earlier"
        case .business: return "Start new business"
        case .kids: return "Raise kids"
        case .travel: return "Travel"
        case .house: return "Buy a house"
        case .car: return "New car"
        case .emergency: return "Build emergency fund"
        case .save: return "Save for better future"
        }
    }

    var emoji: String {
        switch self {
        case .retire: return "🌅"
        case .business: return "🌐"
        case .kids: return "👶"
        case .travel: return "✈️"
        case .house: return "🏠"
        case .car: return "🚗"
        case .emergency: return "👛"
        case .save: return "🐷"
        }
    }
}

enum OccupationOption: String, CaseIterable, Identifiable {
    case employed, freelancer, business, student, sabbatical, unemployed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .employed: return "Employed"
        case .freelancer: return "Freelancer"
        case .business: return "Own Business"
        case .student: return "Student"
        case .sabbatical: return "Sabbatical"
        case .unemployed: return "Unemployed"
        }
    }

    var emoji: String {
        switch self {
        case .employed: return "💼"
        case .freelancer: return "💻"
        case .business: return "🏢"
        case .student: return "🎓"
        case .sabbatical: return "✈️"
        case .unemployed: return "🏠"
        }
    }
}

enum HousingOption: String, CaseIterable, Identifiable {
    case owner, rent_apt, rent_house, coliving

    var id: String { rawValue }

    var label: String {
        switch self {
        case .owner: return "Own Property"
        case .rent_apt: return "Rental Apartment"
        case .rent_house: return "Rental House/Villa"
        case .coliving: return "Co-living / Shared"
        }
    }

    var emoji: String {
        switch self {
        case .owner: return "🏡"
        case .rent_apt: return "🏢"
        case .rent_house: return "🏠"
        case .coliving: return "👥"
        }
    }
}

enum TransportOption: String, CaseIterable, Identifiable {
    case own_car, rental_car, public_transport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .own_car: return "Own Car"
        case .rental_car: return "Rental Car"
        case .public_transport: return "Public Transport"
        }
    }

    var emoji: String {
        switch self {
        case .own_car: return "🚗"
        case .rental_car: return "🚙"
        case .public_transport: return "🚌"
        }
    }
}

enum AgeOption: String, CaseIterable, Identifiable {
    case under_20, twenties = "20s", thirties = "30s", forties = "40s", fifty_plus = "50_plus"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under_20: return "Under 20"
        case .twenties: return "20s"
        case .thirties: return "30s"
        case .forties: return "40s"
        case .fifty_plus: return "50+"
        }
    }
}

// MARK: - Profile View

public struct ProfileView: View {
    public init(onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
    }

    public var body: some View {
        let _ = logger.debug("body rendered - profile: \(profile != nil), isLoadingProfile: \(isLoadingProfile)")
        List {
            if let profile = profile {
                profileSection(profile: profile)
                subscriptionSection(profile: profile)
                preferencesSection(profile: profile)
                notificationsSection(profile: profile)
                apiKeysSection
                actionsSection

                Section {} footer: {
                    LegalFooter()
                        .frame(maxWidth: .infinity)
                }
            } else if isLoadingProfile {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .navigationTitle("Profile")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData(force: true)
        }
    }

    // MARK: - Private

    @Dependency(\.authService) private var authService
    @Dependency(\.accountManager) private var accountManager
    @Dependency(\.profileService) private var profileService
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.targetService) private var targetService
    @Dependency(\.reportService) private var reportService
    @Dependency(\.apiKeyService) private var apiKeyService

    @State private var profile: Servicing.Profile?
    @State private var apiKeys: [Servicing.ApiKey] = []
    @State private var isLoadingProfile = false
    @State private var isUpdating = false
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showCacheResetConfirmation = false
    @State private var showCacheResetSuccess = false
    @State private var isCreatingApiKey = false
    @State private var newApiKeyId: String?

    private let onLogout: (() -> Void)?

    private func loadData(force: Bool = false) async {
        logger.info("loadData started, force: \(force)")
        isLoadingProfile = true
        defer {
            isLoadingProfile = false
            logger.debug("loadData completed")
        }

        do {
            profile = try await profileService.getProfile(force: force)
            logger.info("Profile loaded: \(profile?.displayName ?? "nil")")
        } catch {
            logger.error("Profile loading failed: \(error.localizedDescription)")
        }

        do {
            apiKeys = try await apiKeyService.getApiKeys(force: force)
        } catch {
            logger.error("API keys loading failed: \(error.localizedDescription)")
        }
    }

    private func updateProfile(_ input: UpdateProfileInput) async {
        logger.info("updateProfile called with input")
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updatedProfile = try await profileService.updateProfile(input)
            profile = updatedProfile
            logger.info("Profile updated successfully")
        } catch {
            logger.error("Profile update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Profile Section

    @ViewBuilder
    private func profileSection(profile: Servicing.Profile) -> some View {
        Section {
            HStack(spacing: 16) {
                if let pictureURL = profile.pictureURL {
                    AsyncImage(url: pictureURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 70, height: 70)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if !profile.email.isEmpty {
                        Text(profile.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        } footer: {
            Text("Member since \(formattedDate(profile.createdAt))")
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private func subscriptionSection(profile: Servicing.Profile) -> some View {
        Section("Subscription") {
            LabeledContent("Plan") {
                HStack(spacing: 4) {
                    if profile.isPremium {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    Text(profile.plan.displayName)
                }
            }

            if let startsAt = profile.planStartsAt {
                LabeledContent("Started", value: formattedDate(startsAt))
            }

            if let expiresAt = profile.planExpiresAt {
                LabeledContent("Expires", value: formattedDate(expiresAt))
            }
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private func preferencesSection(profile: Servicing.Profile) -> some View {
        Section("Preferences") {
            NavigationLink {
                MultiSelectView(
                    title: "Main Goal",
                    options: GoalOption.allCases,
                    selected: Set(profile.goals),
                    onUpdate: { newValues in
                        logger.info("Dreams updated: \(newValues)")
                        await updateProfile(UpdateProfileInput(goals: Array(newValues)))
                    }
                )
            } label: {
                LabeledContent("Main Goal") {
                    Text(formatSelected(profile.goals, from: GoalOption.self))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            NavigationLink {
                MultiSelectView(
                    title: "Occupation",
                    options: OccupationOption.allCases,
                    selected: Set(profile.occupation),
                    onUpdate: { newValues in
                        logger.info("Occupation updated: \(newValues)")
                        await updateProfile(UpdateProfileInput(occupation: Array(newValues)))
                    }
                )
            } label: {
                LabeledContent("Occupation") {
                    Text(formatSelected(profile.occupation, from: OccupationOption.self))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            NavigationLink {
                MultiSelectView(
                    title: "Housing",
                    options: HousingOption.allCases,
                    selected: Set(profile.housing),
                    onUpdate: { newValues in
                        logger.info("Housing updated: \(newValues)")
                        await updateProfile(UpdateProfileInput(housing: Array(newValues)))
                    }
                )
            } label: {
                LabeledContent("Housing") {
                    Text(formatSelected(profile.housing, from: HousingOption.self))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            NavigationLink {
                MultiSelectView(
                    title: "Commute",
                    options: TransportOption.allCases,
                    selected: Set(profile.transport),
                    onUpdate: { newValues in
                        logger.info("Commute updated: \(newValues)")
                        await updateProfile(UpdateProfileInput(transport: Array(newValues)))
                    }
                )
            } label: {
                LabeledContent("Commute") {
                    Text(formatSelected(profile.transport, from: TransportOption.self))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            NavigationLink {
                SingleSelectView(
                    title: "Age",
                    options: AgeOption.allCases,
                    selected: profile.age,
                    onUpdate: { newValue in
                        logger.info("Age updated: \(newValue ?? "nil")")
                        await updateProfile(UpdateProfileInput(age: newValue))
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

            NavigationLink {
                CurrencySelectView(
                    selected: profile.currency,
                    onUpdate: { newValue in
                        logger.info("Currency updated: \(newValue ?? "nil")")
                        await updateProfile(UpdateProfileInput(currency: newValue))
                    }
                )
            } label: {
                LabeledContent("Currency") {
                    if let currency = Currency.find(by: profile.currency) {
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
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private func notificationsSection(profile: Servicing.Profile) -> some View {
        Section("Notifications") {
            NotificationToggle(
                title: "Daily Reports",
                isOn: profile.notifyDailyReport
            ) { newValue in
                logger.info("Daily Reports updated: \(newValue)")
                await updateProfile(UpdateProfileInput(notifyDailyReport: newValue))
            }

            NotificationToggle(
                title: "Weekly Reports",
                isOn: profile.notifyWeeklyReport
            ) { newValue in
                logger.info("Weekly Reports updated: \(newValue)")
                await updateProfile(UpdateProfileInput(notifyWeeklyReport: newValue))
            }

            NotificationToggle(
                title: "Monthly Reports",
                isOn: profile.notifyMonthlyReport
            ) { newValue in
                logger.info("Monthly Reports updated: \(newValue)")
                await updateProfile(UpdateProfileInput(notifyMonthlyReport: newValue))
            }

            NotificationToggle(
                title: "Annual Reports",
                isOn: profile.notifyAnnualReport
            ) { newValue in
                logger.info("Annual Reports updated: \(newValue)")
                await updateProfile(UpdateProfileInput(notifyAnnualReport: newValue))
            }
        }
    }

    // MARK: - API Keys Section

    @ViewBuilder
    private var apiKeysSection: some View {
        Section("Devices") {
            ForEach(apiKeys) { apiKey in
                HStack {
                    Image(systemName: "iphone")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(apiKey.name)
                            .font(.body)
                        Text(apiKey.formattedCreatedAt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if apiKey.isActive {
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Inactive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                Task { await addDevice() }
            } label: {
                HStack {
                    Label("Add Device", systemImage: "plus.circle")
                    if isCreatingApiKey {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isCreatingApiKey)

            NavigationLink(isActive: Binding(
                get: { newApiKeyId != nil },
                set: { if !$0 { newApiKeyId = nil } }
            )) {
                if let apiKeyId = newApiKeyId {
                    ConnectDeviceOptionsView(apiKeyId: apiKeyId)
                }
            } label: {
                EmptyView()
            }
            .hidden()
        }
    }

    private func addDevice() async {
        isCreatingApiKey = true
        defer { isCreatingApiKey = false }

        do {
            let deviceName = UIDevice.current.name
            let apiKey = try await apiKeyService.createApiKey(name: deviceName)
            apiKeys = await apiKeyService.cachedApiKeys
            newApiKeyId = apiKey.id
        } catch {
            logger.error("Failed to create API key: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        Section("Actions") {
            Button {
                if let url = URL(string: "mailto:support@dibba.ai") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Contact Support", systemImage: "envelope")
            }

            Button {
                showCacheResetConfirmation = true
            } label: {
                Label("Reset Cache", systemImage: "arrow.triangle.2.circlepath")
            }
            .alert("Reset Cache", isPresented: $showCacheResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    Task {
                        await transactionService.clearCache()
                        await targetService.clearCache()
                        await reportService.clearCache()
                        await profileService.clearCache()
                        await apiKeyService.clearCache()
                        showCacheResetSuccess = true
                    }
                }
            } message: {
                Text("This will clear all cached data. The app will re-download everything on next launch.")
            }
            .alert("Cache Cleared", isPresented: $showCacheResetSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All cached data has been cleared.")
            }

            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    if let url = URL(string: "mailto:support@dibba.ai?subject=Delete%20My%20Account") {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("This will send a request to delete your account and all associated data. This action cannot be undone.")
            }

            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    onLogout?()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

// MARK: - Notification Toggle

private struct NotificationToggle: View {
    let title: String
    let isOn: Bool
    let onUpdate: (Bool) async -> Void

    @State private var localIsOn: Bool = false
    @State private var isUpdating = false

    init(title: String, isOn: Bool, onUpdate: @escaping (Bool) async -> Void) {
        self.title = title
        self.isOn = isOn
        self.onUpdate = onUpdate
        self._localIsOn = State(initialValue: isOn)
    }

    var body: some View {
        Toggle(isOn: $localIsOn) {
            HStack(spacing: 8) {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Text(title)
            }
        }
        .disabled(isUpdating)
        .onChange(of: localIsOn) { _, newValue in
            guard newValue != isOn, !isUpdating else { return }
            Task {
                isUpdating = true
                await onUpdate(newValue)
                isUpdating = false
            }
        }
        .onChange(of: isOn) { _, newValue in
            localIsOn = newValue
        }
    }
}

// MARK: - Multi Select View

private struct MultiSelectView<Option: Identifiable & RawRepresentable>: View where Option.RawValue == String {
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

// MARK: - Single Select View

private struct SingleSelectView<Option: Identifiable & RawRepresentable>: View where Option.RawValue == String {
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

// MARK: - Currency Select View

private struct CurrencySelectView: View {
    let selected: String?
    let onUpdate: (String?) async -> Void

    @State private var localSelected: String?
    @State private var searchText = ""
    @State private var isUpdating = false

    init(selected: String?, onUpdate: @escaping (String?) async -> Void) {
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

    var body: some View {
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
