# LimitRoom Native Foundation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for native execution. The user's no-new-tests-without-assigned-IDs rule overrides generated test steps. No ID is currently assigned.

**Goal:** Produce a buildable native macOS application with truthful source states, quota selection, local history, and reusable allowance models.

**Architecture:** Xcode app and helper targets consume a local Swift package. Core rules are pure; connectors hide source formats; a single history writer and monitor feed the UI.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SQLite3, Charts, ServiceManagement, WebKit. Sparkle is integrated only after an update channel is configured.

**Spec:** `docs/architecture.md`.

**Scope of checked items:** implementation and builds for this foundation, not a certified release. Live-source, OS-permission, accessibility and native-window checks remain explicitly separated in `docs/verification.md`.

## Global Constraints

- macOS 14+, arm64 and x86_64.
- Codex, Claude Code, Cursor only; one active account each.
- Russian and English follow macOS locale.
- Local history: 90 days; no conversation or credential collection.
- No new automated tests without assigned test-case IDs; run builds and record manual evidence instead.
- No public releases, owner token embedded in app, or automatic changes to agent settings.

## Review Focus

- Missing or stale data must never render as a full or empty live allowance.
- Reset, account change and gaps must not create false consumption spikes.
- Duplicate observations must not inflate history or alerts.
- Demo data must never persist, alert, or masquerade as personal usage.

### Task 1: Core model and observed trends

**Files:** `Package.swift`, `Sources/AllowanceCore/Models.swift`, `Sources/AllowanceCore/Trends.swift`.

**Interfaces:** produces `AgentSnapshot`, `AllowanceWindow`, `WindowSelection`, `HistorySample`, `TrendCalculator.rates(from:)`.

- [x] Define sendable/codable values and independent source/freshness states.
- [x] Use stable window selection rather than pinning a reading object.
- [x] Implement comparable-cycle deltas with a 30-minute gap limit, minimum 60-second interval, and explicit percentage-point unit.
- [x] Run `swift build --target AllowanceCore`; expected: compilation succeeds.

### Task 2: History storage

**Files:** `Sources/CSQLite/*`, `Sources/AllowanceStorage/HistoryStore.swift`.

**Interfaces:** consumes `AgentSnapshot`; produces `HistoryStore.record(_:now:)`, `samples(since:)`, `removeAll()`, `exportJSON()`.

- [x] Use prepared statements, schema version and one writer; unique identity includes account/window/time.
- [x] Purge observations older than 90 days, export only allowlisted metrics.
- [x] Run `swift build --target AllowanceStorage`; expected: compilation succeeds.

### Task 3: Read-only connectors

**Files:** `Sources/AllowanceConnectors/Connector.swift`, `CodexConnector.swift`, `ClaudeConnector.swift`, `Sources/ClaudeBridge/main.swift`.

**Interfaces:** `AllowanceConnector.read() async throws -> AgentSnapshot`; failures become typed setup/unavailable states.

- [x] Codex: stdio RPC handshake, read-only account and rate-limit methods; bounded process lifetime and no transcript access.
- [x] Claude: consume quota-only bridge file, preserve its observation timestamp, provide an explicit setup snippet.
- [x] Bridge: project incoming statusLine JSON to rate-limit fields; never open its transcript path.
- [x] Cursor: start as clearly unconnected; the app owns isolated web login and validates the source before reporting live support.
- [x] Run `swift build --target AllowanceConnectors` and `swift build --product limitroom-claude-bridge`; expected: compilation succeeds.

### Task 4: Monitor and platform behavior

**Files:** `Sources/AllowanceRuntime/AllowanceMonitor.swift`, `App/AppModel.swift`, `App/PlatformSettings.swift`.

**Interfaces:** consumes connectors and history; produces observable agent states, pinned window, chart samples and settings.

- [x] Coalesce refresh, preserve last good values on failure, compute staleness from observation time/reset.
- [x] Fetch each source independently every five minutes and on wake/manual request.
- [x] Keep demo mode separate from storage and notifications.
- [x] Register launch at login only after onboarding choice; honor actual SMAppService status.
- [x] Notify only for fresh threshold crossings, disabled by default.

### Task 5: Native UI and source setup

**Files:** `App/LimitRoomApp.swift`, `App/DashboardView.swift`, `App/HistoryView.swift`, `App/SettingsView.swift`, `App/CursorSignIn.swift`, `App/Localization.swift`.

**Interfaces:** app observes `AppModel`; UI actions refresh, pin windows, open settings/history and explicit source login.

- [x] Implement menu-bar half gauge + remaining percentage, compact overview and detailed windows.
- [x] Add Charts history, export, clear-history confirmation and source settings.
- [x] Add isolated Cursor WebKit sign-in without browser cookie import; distinguish successful login from verified usage data.
- [x] Honor light/dark appearance, Reduce Motion, keyboard and VoiceOver; localize visible copy.
- [x] Run `swift build --product LimitRoom`; expected: compilation succeeds.

### Task 6: Application packaging

**Files:** `LimitRoom.xcodeproj/project.pbxproj`, `Config/*`, `Scripts/build-app.sh`.

**Interfaces:** the app composes the package modules; the helper links only AllowanceCore.

- [x] Add Xcode targets/schemes and configurable signing; never fabricate a Team ID.
- [x] Provide local app build command and verify both architectures; installed-app behavior remains a separately recorded verification.

### Task 7: Review and evidence

**Files:** `README.md`, `docs/verification.md`, `docs/implementation-progress.md`.

- [x] Record exactly which builds, live integrations and installed behaviors were verified.
- [x] Request a fresh whole-change review, fix material findings, rebuild affected targets.
- [x] Commit local implementation (`e734aa0`). Browser login is not Git authentication; push remains a separate blocked step.

## Initial plan review

The interfaces form a directed graph: Core → Storage/Connectors → Runtime → App. Export and notifications use already projected values. A source spike may fail independently while the native app remains usable; no unverified integration is reported as complete.
