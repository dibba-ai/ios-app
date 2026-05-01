# AGENTS.md — Dibba Mobile App

This file is the single source of truth for all AI agents working with this codebase.
Compatible with Cursor, Claude Code, Codex, Copilot, and any AI tool that reads AGENTS.md.

## Project Context

- **Dibba.ai**: experimental AI-powered budgeting mobile app (powered with backend)
- **Key principle**: speed of iteration > production-readiness. Hackathon-style build.
- **Tech stack**: Swift
- **References**: `docs/architecture.md` (system overview, API catalog), `docs/adr/` (architectural decisions)

## Development Workflow

Follow the **Plan-Execute-Verify** loop for every task:

1. **READ** — Understand current code, related files, types, tests
2. **PLAN** — Define what to build, what tests to write, what files to touch
3. **TEST** — Write failing test(s) for the desired behavior (TDD)
4. **BUILD** — Implement the minimum code to pass the tests
5. **VERIFY** — Run `pnpm lint && pnpm typecheck && pnpm test:ci`. All must pass.
6. **DOCS** — Update CHANGELOG.md. Create ADR if an architectural decision was made.
7. **NEXT** — Move to next task. No gold-plating.

Additional rules:

- **Fail fast**: if an approach fails twice, reassess and try a different approach
- **No premature abstraction**: extract patterns only when repeated 3+ times
- **Parallel execution**: independent tasks (API routes, components) can run simultaneously
- **Prompts are data**: stored in `lib/prompts/` as template functions, not hardcoded strings
- **Each external API has one wrapper**: `lib/sdk/openai.ts`, `lib/sdk/elevenlabs.ts`. Swapping a provider = changing one file.

**Quality gates** — before moving to the next task, ALL must pass:

```bash
xcodebuild
```


## Architecture

- **Tuist-based project**: Uses Tuist for project generation and modular architecture
- **Swift Package modules**: Features are separated into individual packages in the `Packages/` directory:
  - ApiClient - API communication, network
  - Auth - User authentication and session management
  - Core - Shared utilities and core functionality
  - Dashboard - Main Dashboard page components
  - Database - GRDB-backed local cache (transactions, sync cursors); mirror of server state
  - Debug - Debug-only screens and tooling (gated easter-egg entry)
  - Feed - Feed page functionality
  - Navigation - App navigation and routing
  - Onboarding - User onboarding flows
  - Profile - Profile and Settings page functionality
  - Servicing - Service layer abstractions (wraps ApiClient + Database)
  - State - Shared app-level state primitives
  - UI - Shared SwiftUI components and design tokens
  - Auth0 - External package handles tokens via Auth0
- **MVVM with SwiftUI**: View models use `@Observable` for state management
- **Dependency injection**: Services are injected through protocols



## Code Style

TODO: add code style

## API Routes (app/api/**)

TODO: add code style


## Testing (*.test.ts, *.test.tsx)

TODO: add testing 

## ADR Process (docs/adr/)

- Format: MADR (Markdown Any Decision Records)
- File naming: `NNNN-short-title.md` (zero-padded 4 digits)
- Required sections: Status, Date, Context, Decision, Alternatives Considered, Consequences
- **Rule**: for any significant architectural change — write ADR first, then implement

## Change Management (CHANGELOG.md)

- Format: [Keep a Changelog](https://keepachangelog.com/)
- Categories: Added, Changed, Fixed, Removed, Security
- Update CHANGELOG at the end of each phase or significant change
- On deploy: `[Unreleased]` section becomes a versioned release with date

## Design System

TODO: add design system

## UX Flow

TODO: add UX flow

- When modifying UI components, avoid adding always-visible padding or layout shifts for loading states (e.g., spinners). Use inline or overlay indicators that don't affect layout when hidden.

## Authentication

- **Auth0** (client-side) handles Google, Apple, email/password sign-in
- **GraphQL API** provides data to support mobile app (profile, settings, transactions, goals, etc)

## Data Management and GraphQL API

- GraphQL API is the **sole source of truth** for all user data. The mobile app is a thin client.
- **Local database (GRDB) is used as a cache layer only.** Persisted via the `Database` package (`Packages/Database/`) and accessed through `Servicing` services (e.g., `transactionStore`). It mirrors a subset of server data for offline reads, fast pagination, and reactive UI via change observation. The DB never holds user-authored state that doesn't exist on the server — invalidation/refresh always reconciles against GraphQL.
- Treat the local DB as **derived state**: any record can be evicted and re-fetched without data loss. If a feature needs durable client-only state, propose a server-side schema first.
- `UserDefaults` is allowed for ephemeral flags only (sync cursors, onboarding flags, last-selected pickers) — never for entity data.
- Prefer incremental cache-sync strategies over force-refresh/full-reload approaches for data fetching.
- Always propose the least disruptive data update pattern first.
- **Token flow**: Auth0 token used to authenticate

**Implemented endpoints:**

| Module | Functions | Source |
|--------|-----------|--------|


## Key Components



## Anti-Patterns (Explicitly Avoid)

- Monolithic files (>200 lines = split it)
- God components / god hooks that do everything
- Shared mutable state between API routes
- Over-engineering before we have working features
- Premature abstraction ("we might need this later")
- Analysis paralysis — make a decision, test it, move on
