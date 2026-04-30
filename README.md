# Dibba iOS App

Experimental AI-powered budgeting app for iOS. Native Swift / SwiftUI client backed by GraphQL services and Auth0.

> **Status:** Hackathon-style build. Speed of iteration over production-readiness.

---

## Table of Contents

- [Project Information](#project-information)
- [Features](#features)
- [Architecture](#architecture)
- [API Information](#api-information)
- [Build & Run](#build--run)
- [Testing](#testing)
- [Development Guidelines](#development-guidelines)

---

## Project Information

| Item | Value |
|------|-------|
| Platform | iOS 17+ |
| Language | Swift 6.x |
| UI Framework | SwiftUI |
| Concurrency | Swift Concurrency (`async`/`await`, actors) |
| Auth | Auth0 (Google, Apple, email/password) |
| Backend | GraphQL (api / identity / billing services) |
| Project Layout | Modular Swift Packages under `Packages/` |
| Dependency Injection | [`pointfreeco/swift-dependencies`](https://github.com/pointfreeco/swift-dependencies) |
| Min Xcode | 16+ recommended |

---

## Features

- **Authentication** — Auth0-backed sign-in (Google, Apple, email/password); session and account state management.
- **Onboarding** — first-launch flow for new users.
- **Dashboard** — primary landing surface summarizing budget state.
- **Feed** — activity / transaction feed.
- **Profile & Settings** — user profile, account settings, device management, sign-out / app-reset.
- **Transactions** — list, create, update, delete with paginated `nextToken` cursor.
- **Targets** — list / create / update budgeting targets.
- **Reports** — fetch reports by ID set.
- **API Keys** — list and create API keys (developer surface).
- **Billing** — subscription / billing service integration.

---

## Architecture

### Modular Swift Packages

The app is split into independent Swift Packages under `Packages/`. The Xcode app target (`ios/`) is a thin shell that composes these modules.

```
ios/                          # App target — entry point, AppCoordinator, Assets
ios.xcodeproj/                # Xcode project
Packages/
├── ApiClient/                # GraphQL client, DTOs, queries, middleware
├── Auth/                     # Auth0 wrapper, AccountManager, AuthFlow, LoginView
├── Core/                     # Shared utilities
├── Data/                     # Cache / data layer primitives
├── Dashboard/                # Dashboard feature
├── Feed/                     # Feed feature
├── Features/                 # Cross-feature composition
├── Navigation/               # Routing / coordinators
├── Onboarding/               # First-launch onboarding
├── Profile/                  # Profile + Settings
├── Servicing/                # Service-layer protocols (Profile/Target/Transaction/Report/ApiKey/Billing)
├── State/                    # Observable app state
└── UI/                       # Design system / shared SwiftUI components
SupportingFiles/              # Info.plist
Auth0.plist                   # Auth0 client config
AGENTS.md / CLAUDE.md         # AI agent instructions
```

### Module Dependency Direction

```
App (ios/)
  └── Features → Dashboard / Feed / Onboarding / Profile
        └── Servicing → ApiClient → Auth
              └── Core / State / Data / UI / Navigation
```

Lower-level modules (`Core`, `Auth`, `ApiClient`) never import higher-level feature modules.

### Patterns

- **MVVM + SwiftUI** — view models use `@Observable`.
- **Protocol-oriented services** — every service has a protocol; concrete impls injected via `swift-dependencies`.
- **Thin client** — GraphQL API is the **sole source of truth** for user data. App keeps cache only, no local DB.
- **One wrapper per external SDK** — swap providers by editing one file.
- **Incremental cache sync** preferred over full reload.

### Auth Flow

1. Auth0 SDK handles sign-in (Google / Apple / email-password).
2. Auth0 issues access token.
3. `ApiClient` attaches token to every GraphQL request via middleware.
4. `AccountManager` / `AuthState` track session; `AppResetService` clears state on sign-out.

---

## API Information

The mobile app talks to three GraphQL endpoints (defined in `Packages/ApiClient/Sources/ApiClient/ApiClient.swift`):

| Service | URL |
|---------|-----|
| API | `https://api-service.dibba.ai/graphql` |
| Identity | `https://id.dibba.ai/graphql` |
| Billing | `https://billing-service.dibba.ai/graphql` |

### `APIClienting` Protocol

| Domain | Operations |
|--------|------------|
| Profile | `getProfile`, `updateProfile` |
| Transactions | `listTransactions(nextToken:perPage:)`, `createTransaction`, `updateTransaction`, `deleteTransaction` |
| Targets | `listTargets`, `createTarget`, `updateTarget` |
| Reports | `listReports(ids:)` |
| API Keys | `listApiKeys`, `createApiKey` |

GraphQL operations live in `Packages/ApiClient/Sources/ApiClient/Queries/`. DTOs live in `DTOs/`. Auth/header injection lives in `Middleware/`.

### Service Layer

`Packages/Servicing` exposes the higher-level interfaces consumed by feature modules:

- `ProfileService`
- `TransactionService`
- `TargetService`
- `ReportService`
- `ApiKeyService`
- `BillingService`

Each conforms to `StateResetting` so `AppResetService` can wipe caches on sign-out.

---

## Build & Run

### Prerequisites

- macOS with Xcode 16+
- iOS 17+ simulator or device
- Auth0 client credentials (already wired in `Auth0.plist`)

### Open in Xcode

```bash
open ios.xcodeproj
```

Select the `ios` scheme and a simulator, then **Run** (`⌘R`).

### Build from CLI

```bash
xcodebuild \
  -project ios.xcodeproj \
  -scheme ios \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

### Resolve Swift Package Dependencies

Xcode resolves automatically on open. To force resolution from CLI:

```bash
xcodebuild -resolvePackageDependencies -project ios.xcodeproj
```

---

## Testing

Tests live in two places:

- **App-level tests** — `iosTests/` (unit), `iosUITests/` (UI).
- **Package tests** — each Swift Package has its own `Tests/` directory (e.g. `Packages/ApiClient/Tests/`).

### Run all app tests

```bash
xcodebuild test \
  -project ios.xcodeproj \
  -scheme ios \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Run a package's tests

```bash
cd Packages/ApiClient
swift test
```

### Quality Gate

Before moving to the next task, the build must pass:

```bash
xcodebuild
```

---

## Development Guidelines

Distilled from `AGENTS.md`. Read that file for the full version.

### Plan-Execute-Verify Loop

1. **READ** — understand current code, types, tests.
2. **PLAN** — define what to build, what to test, what files to touch.
3. **TEST** — write failing tests first (TDD where practical).
4. **BUILD** — minimum code to pass.
5. **VERIFY** — `xcodebuild` must succeed.
6. **DOCS** — update `CHANGELOG.md`; write an ADR if architectural.
7. **NEXT** — no gold-plating.

### Rules

- **Fail fast.** If an approach fails twice, reassess.
- **No premature abstraction.** Extract when repeated 3+ times.
- **Parallel where independent.** Independent features / API routes can run in parallel.
- **One wrapper per external API.** Swap = change one file.
- **Least-disruptive data updates.** Prefer incremental cache sync over force-refresh.
- **No always-visible padding for loading states.** Use inline / overlay indicators that don't shift layout.

### Anti-Patterns (Avoid)

- Files > 200 lines — split.
- God components / god view models.
- Shared mutable state across features.
- Over-engineering before working features exist.
- Premature abstraction ("we might need this later").
- Analysis paralysis — decide, test, move on.

### ADRs

- Format: MADR (Markdown Any Decision Records).
- Location: `docs/adr/`.
- Filename: `NNNN-short-title.md` (zero-padded).
- Sections: Status, Date, Context, Decision, Alternatives Considered, Consequences.
- **Write the ADR before implementing** any significant architectural change.

### Changelog

- Format: [Keep a Changelog](https://keepachangelog.com/).
- Categories: Added, Changed, Fixed, Removed, Security.
- Update at end of each phase / significant change.
- On deploy: `[Unreleased]` becomes a versioned, dated release.

---

## References

- [`AGENTS.md`](./AGENTS.md) — single source of truth for AI agents and contributors
- [`CLAUDE.md`](./CLAUDE.md) — re-exports `AGENTS.md` for Claude Code
- `docs/architecture.md` — system overview (when present)
- `docs/adr/` — architectural decision records (when present)
