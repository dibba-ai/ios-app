# Voice Logging via App Intents — Implementation Plan

Status: Draft. Iterating phase by phase.

## Goal

Enable users to record purchases, income, and transfers by voice via Siri / App Shortcuts, mirroring the manual entry flow at `Packages/Feed/Sources/Feed/AddPurchase/AddPurchaseView.swift`.

## Framework Choice

App Intents (iOS 16+), not legacy SiriKit / `INIntent`. Reason: HIG (Apple, June 2023) deprecated "Add to Siri" in favor of App Shortcuts. No system Payments domain match (`INSendPayment` ≠ logging your own ledger). Use **custom App Intent** in `order` category — HIG: financial-impact category forces confirm phase + auth context.

## Decisions (Locked)

| # | Decision |
|---|---|
| 1 | Currency default = profile currency. User-spoken currency overrides via alias map. |
| 2 | Auth: in-process v1 (no extension target). Move to App Group + extension only if perf is bad. |
| 3 | Three intents (`LogPurchaseIntent`, `LogIncomeIntent`, `LogTransferIntent`). Mapping table below. |
| 4 | Account/card field left empty (matches current manual flow). |
| 5 | Date hardcoded to `Date.now` v1. Natural-language date parsing in backlog. |
| 6 | Auto-confirm every transaction. No follow-up prompt. User deletes in UI if wrong. |
| 7 | No donations v1. |
| 8 | Localization v1 = en + ru + ar. Architecture supports adding fr/de/es/etc. without refactor. |
| 9 | Errors: speak "Sign in to Dibba to log transactions" on unauthorized; warning dialog on other failures; silent currency fallback to profile default if alias unrecognized. |
| 10 | Aliases v1 = en + ru + ar per currency. Native-speaker review post-launch. |

## Transaction Mapping

| Spoken intent | Verb examples | `isPurchase` | `isTransfer` | `isAtm` | `isDebit` | `isCredit` | `transactionType` |
|---|---|---|---|---|---|---|---|
| Purchase | "spent", "bought", "paid for" | true | false | false | true | false | `posPurchase` |
| Income | "received", "got paid", "earned" | false | true | false | false | true | `transfer` |
| Transfer out | "sent", "transferred to", "moved out" | false | true | false | true | false | `transfer` |
| Transfer in | "got transfer", "received transfer" | false | true | false | false | true | `transfer` |
| ATM withdrawal *(v2)* | "withdrew", "took out cash", "ATM" | false | false | true | true | false | `atm` |

## Confirmed Facts

- `Servicing.Currency` (`Packages/Servicing/Sources/Servicing/Models/Currency.swift`) is the canonical type used by Feed, Onboarding, CurrencySelectView, PreferencesSection.
- `Packages/Core/Sources/Core/Models/Currency.swift` is a duplicate — flagged for cleanup, not blocking.
- Profile has `currency: String?` (`PreferencesSection.swift:134`).
- iOS 17 deployment target (App Intents iOS 16+ compatible).
- `CreateTransactionInput` shape from `AddPurchaseView.swift:142`:
  - `name`, `amount`, `currency`, `isCredit`, `isDebit`, `isAtm`, `isPurchase`, `isTransfer`, `fullDate` (yyyy-MM-dd, UTC).
- `transactionService.createTransaction(input)` returns `Servicing.Transaction` (`TransactionService.swift:177`).
- Auth via Auth0 + `@Dependency(\.authService)`; token plumbed by `AuthTokenProvider` (`ApiClient.swift:199`).

---

## Phase 0 — Prep / Currency Consolidation (45 min)

`Currency` is a core entity. Single source of truth = `Packages/Core/Sources/Core/Models/Currency.swift`. Servicing's duplicate gets deleted.

- [x] **0.1** Delete `Packages/Servicing/Sources/Servicing/Models/Currency.swift`.
- [x] **0.2** Add Core dep to `Packages/Servicing/Package.swift`:
  ```swift
  dependencies: [
      .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
      .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
      .package(path: "../APIClient"),
      .package(path: "../Database"),
      .package(path: "../Core"),
  ],
  targets: [
      .target(
          name: "Servicing",
          dependencies: [
              .product(name: "Dependencies", package: "swift-dependencies"),
              .product(name: "Sharing", package: "swift-sharing"),
              .product(name: "ApiClient", package: "APIClient"),
              "Database",
              "Core",
          ]
      ),
      ...
  ]
  ```
- [x] **0.3** Add `import Core` to Servicing files that referenced the local `Currency`:
  - `Packages/Servicing/Sources/Servicing/Views/CurrencySelectView.swift`
  - any other Servicing source using `Currency.allCurrencies` / `Currency.find(by:)`
- [x] **0.4** Fix consumer imports (these import Servicing and use `Currency`):
  - `Packages/Feed/Sources/Feed/AddPurchase/AddPurchaseView.swift` — verify Feed pkg has Core dep, add if missing; ensure file `import Core`.
  - `Packages/Onboarding/Sources/Onboarding/Screens/CurrencyScreen.swift` — same.
  - `Packages/Profile/Sources/Profile/Sections/PreferencesSection.swift:141` — change `Servicing.Currency.find(by:)` → `Currency.find(by:)` (Profile already `import Core`).
- [x] **0.5** `xcodebuild` → resolve any leftover unresolved imports.
- [x] **0.6** Confirm Phase 2 will validate `@Dependency` resolution from `AppIntent.perform()` (R1 spike). No work in Phase 0.

## Phase 1 — Currency Aliases (1.5h)

**File**: `Packages/Core/Sources/Core/Models/Currency.swift`

- [x] **1.1** Add `aliases: [String]` field. Lowercase normalization in init.
  ```swift
  public let aliases: [String]

  public init(
      id: String, label: String, emoji: String,
      continent: String, timezones: [String],
      aliases: [String] = []
  ) {
      self.id = id
      self.label = label
      self.emoji = emoji
      self.continent = continent
      self.timezones = timezones
      self.aliases = aliases.map { $0.lowercased() }
  }
  ```

- [x] **1.2** Fill aliases en+ru+ar for all 40 currencies. Pattern:
  ```swift
  Currency(id: "RUB", label: "Russian Rubles", emoji: "🇷🇺", continent: "Europe", timezones: [...],
           aliases: [
              "ruble", "rubles", "rub",
              "рубль", "рубли", "рублей", "руб",
              "روبل", "روبل روسي",
           ])
  ```
  Skip ambiguous symbols (`$`, etc.).

- [x] **1.3** Add lookup helper:
  ```swift
  public extension Currency {
      static func find(byAlias term: String) -> Currency? {
          let needle = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
          guard !needle.isEmpty else { return nil }
          if let exact = allCurrencies.first(where: { $0.id.lowercased() == needle }) {
              return exact
          }
          return allCurrencies.first { $0.aliases.contains(needle) }
      }
  }
  ```

- [x] **1.4** Unit tests at `Packages/Core/Tests/CoreTests/CurrencyAliasTests.swift`:
  - `find(byAlias: "dollars")` → USD
  - `find(byAlias: "рубли")` → RUB
  - `find(byAlias: "درهم")` → AED
  - `find(byAlias: "USD")` → USD (case-insensitive)
  - `find(byAlias: "")` → nil
  - `find(byAlias: "xyz")` → nil
  - `find(byAlias: "$")` → nil (ambiguous)

## Phase 2 — Intents Package (4-6h)

- [x] **2.1** Create `Packages/Intents/` SPM module.
  ```
  Packages/Intents/
  ├── Package.swift
  ├── Sources/Intents/
  │   ├── LogPurchaseIntent.swift
  │   ├── LogIncomeIntent.swift
  │   ├── LogTransferIntent.swift
  │   ├── Resolvers/CurrencyResolver.swift
  │   ├── Errors/IntentError.swift
  │   └── Snippets/TransactionLoggedSnippet.swift
  └── Tests/IntentsTests/
  ```
  `Package.swift` deps: `Servicing`. Platform `.iOS(.v17)`.

- [x] **2.2** `LogPurchaseIntent`:
  ```swift
  struct LogPurchaseIntent: AppIntent {
      static var title: LocalizedStringResource = "Log Purchase"
      static var description = IntentDescription("Record a purchase by voice")
      static var openAppWhenRun: Bool = false

      @Parameter(title: "Amount") var amount: Double
      @Parameter(title: "Currency") var currencyTerm: String?
      @Parameter(title: "Description") var note: String?

      @Dependency(\.transactionService) private var transactionService
      @Dependency(\.profileService) private var profileService

      static var parameterSummary: some ParameterSummary {
          Summary("Log purchase of \(\.$amount) \(\.$currencyTerm) for \(\.$note)")
      }

      func perform() async throws -> some IntentResult & ProvidesDialog {
          guard amount > 0 else { throw IntentError.invalidAmount }
          let currency = await CurrencyResolver.resolve(term: currencyTerm, profileService: profileService)
          let name = (note?.trimmingCharacters(in: .whitespaces).nilIfEmpty) ?? "Purchase"

          let input = CreateTransactionInput(
              name: name, amount: amount, currency: currency,
              isCredit: false, isDebit: true,
              isAtm: false, isPurchase: true, isTransfer: false,
              fullDate: Self.todayISO()
          )
          do { _ = try await transactionService.createTransaction(input) }
          catch { throw IntentError.from(error) }

          return .result(dialog: "Logged \(amount) \(currency) for \(name).")
      }
  }
  ```

- [x] **2.3** `LogIncomeIntent` — `isCredit=true, isDebit=false, isTransfer=true, isPurchase=false`. Default name = "Income".

- [x] **2.4** `LogTransferIntent` w/ `direction: TransferDirection` enum (`incoming` / `outgoing`).
  - `outgoing`: `isDebit=true, isTransfer=true`
  - `incoming`: `isCredit=true, isTransfer=true`

- [x] **2.5** `CurrencyResolver`:
  ```swift
  enum CurrencyResolver {
      static func resolve(term: String?, profileService: ProfileServicing) async -> String {
          if let term, let hit = Currency.find(byAlias: term) { return hit.id }
          let cached = await profileService.cachedProfile?.currency
          return cached?.nilIfEmpty ?? "USD"
      }
  }
  ```

- [x] **2.6** `IntentError`:
  ```swift
  enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
      case unauthorized, network, invalidAmount, server(String)

      var localizedStringResource: LocalizedStringResource {
          switch self {
          case .unauthorized: "Sign in to Dibba to log transactions."
          case .network: "Couldn't reach Dibba. Try again."
          case .invalidAmount: "Amount must be greater than zero."
          case .server(let msg): "Couldn't log transaction: \(msg)"
          }
      }

      static func from(_ error: Error) -> IntentError {
          if case APIClientError.unauthorized = error { return .unauthorized }
          if (error as NSError).domain == NSURLErrorDomain { return .network }
          return .server(error.localizedDescription)
      }
  }
  ```

## Phase 3 — Wire Into App (1h)

- [x] **3.1** Add `Intents` package to main app target deps in `Dibba.xcodeproj`.
- [x] **3.2** Add `ios/AppShortcuts/DibbaAppShortcuts.swift`:
  ```swift
  struct DibbaAppShortcuts: AppShortcutsProvider {
      static var appShortcuts: [AppShortcut] {
          AppShortcut(intent: LogPurchaseIntent(),
                      phrases: ["Log purchase in \(.applicationName)",
                                "I spent in \(.applicationName)",
                                "Spent with \(.applicationName)"],
                      shortTitle: "Log Purchase",
                      systemImageName: "creditcard")
          AppShortcut(intent: LogIncomeIntent(),
                      phrases: ["Log income in \(.applicationName)",
                                "Received with \(.applicationName)",
                                "I got paid in \(.applicationName)"],
                      shortTitle: "Log Income",
                      systemImageName: "arrow.down.circle")
          AppShortcut(intent: LogTransferIntent(),
                      phrases: ["Log transfer in \(.applicationName)",
                                "Move money in \(.applicationName)"],
                      shortTitle: "Log Transfer",
                      systemImageName: "arrow.left.arrow.right")
      }
  }
  ```
  `AppShortcutsProvider` MUST live in main app target (not extension/SPM).

- [x] **3.3** Entitlements / Info.plist:
  - `Info.plist`: `NSSiriUsageDescription = "Dibba uses Siri to log transactions by voice."`
  - Capability: enable **Siri** in Signing & Capabilities.

- [x] **3.4** Privacy: confirm no `INRequestSiriAuthorization` needed. HIG: "Don't request permission to use Siri" for App Intents-only apps.

## Phase 4 — Localization (2h)

- [x] **4.1** `AppShortcuts.strings` per locale:
  - `en.lproj` — phrases as defined.
  - `ru.lproj` — "Записать покупку в Dibba", "Я потратил в Dibba", ...
  - `ar.lproj` — "سجل عملية شراء في Dibba", ...

- [x] **4.2** Mark all `LocalizedStringResource` strings — auto-pulls per-locale `.strings` when packaged.

- [x] **4.3** Manual test in Settings → switch device language → verify Siri offers correct phrases.

## Phase 5 — Manual QA (2h)

- [ ] "Hey Siri, log purchase in Dibba" → asks amount → "10 dollars" → confirms → server creates txn
- [ ] "Hey Siri, I spent 10 dollars on coffee in Dibba" → one-shot all params → success
- [ ] "Hey Siri, я потратил 500 рублей на кофе в Dibba" (ru, RUB)
- [ ] Profile=AED, "spent 10 dollars" → currency=USD (override)
- [ ] Profile=AED, "spent 10 on lunch" (no currency) → currency=AED (default)
- [ ] Spoken "twenty bucks" → amount=20, currency=USD
- [ ] Income: "I got paid 5000 dollars salary"
- [ ] Transfer: "Log outgoing transfer 100 dollars"
- [ ] Signed-out → speaks "Sign in to Dibba to log transactions."
- [ ] Airplane mode → speaks "Couldn't reach Dibba. Try again."
- [ ] Verify txn shows in Feed after voice creation
- [ ] Verify `transactionService` updates local DB (cache reactivity)

## Phase 6 — Risks / Validation Spikes

- **R1 — Auth from intent ctx**: `@Dependency(\.authService)` may not auto-resolve if app process not started. Spike during Phase 2.2 — call test intent w/ app killed. If broken → either pre-warm auth in `iosApp.init` or move to extension target w/ App Group + shared Keychain.
- **R2 — `cachedProfile` empty after fresh install**: profile cache may be nil before first dashboard load. Fallback chain `cached → "USD"` handles it.
- **R3 — Phrase ambiguity**: "spent" intent vs system Reminders. Test on device.
- **R4 — App Shortcuts compile-time strings**: phrases must be string literal w/ `AppShortcutPhrase`, not runtime. Localized via `.strings` files only. Confirmed possible.

## Phase 7 — Backlog (post-v1)

- [ ] Date param ("yesterday", "last Friday") via `@Parameter var date: Date?`
- [ ] ATM withdrawal intent
- [ ] Donate intents on every manual add for Siri Suggestions
- [ ] App Group + extension target if perf bad
- [ ] Locales: fr, de, es, tr, ja, zh, pt, hi
- [ ] Account/card param
- [ ] Multi-currency aliases sourced from native speakers
- [ ] Snippet UI: visual receipt w/ category emoji + amount
- [ ] Cleanup `Core/Models/Currency.swift` duplicate
- [ ] Watch + CarPlay testing

## Effort Estimate

| Phase | Hours |
|---|---|
| 0 — Prep | 0.25 |
| 1 — Currency aliases | 1.5 |
| 2 — Intents pkg | 4–6 |
| 3 — Wire into app | 1 |
| 4 — Localization | 2 |
| 5 — Manual QA | 2 |
| **Total v1** | **~12h** |

Critical path = Phase 2 R1 spike. If auth-from-intent works in-process, rest is straight code. If not, +4h for extension target setup.
