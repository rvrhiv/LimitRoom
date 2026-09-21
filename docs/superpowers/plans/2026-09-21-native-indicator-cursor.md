# Native indicator and Cursor connection implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. Steps use checkbox syntax for tracking.

**Goal:** Resolve the six reported presentation/authentication issues and produce a local testable Release build.

**Architecture:** Keep SwiftUI cards and MenuBarExtra. Flatten only the status label to a template image. Isolate Cursor local credentials and first-party HTTP in a connector actor; AppModel owns explicit source selection and invalidation.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Foundation URLSession, SQLite, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-09-21-native-indicator-cursor-design.md`

## Global Constraints

- One account per agent, RU/EN, macOS 14+, local history and no LimitRoom backend remain unchanged.
- No new tests without an actual assigned test-case ID; use existing checks and mark manual gaps.
- No push, installed-app replacement, live credential reads or Claude configuration changes.
- No browser-cookie import, Keychain access, token refresh/persistence/logging or team totals.

## Review Focus

- Native MenuBarExtra flattens custom labels; preview must share the generated image and real status-item output must be inspected.
- NSPanel floating setup must not reset its final level; Spaces changes must not call unconditional hide.
- Local account changes or disconnect during network await must never publish the previous account or cached live percentage.
- SQLite WAL/UTF-16/invalid JWT/expired sessions must fail safely without modifying Cursor storage.
- HTTP redirects, large/error payloads and absent quota fields must not leak credentials or turn unknown quota into zero.

### Task 1: Native presentation repair

**Files:** Modify `App/CompactIndicatorView.swift`, `App/LimitRoomApp.swift`, `App/PresentationSettingsView.swift`, `App/AgentCard.swift`, `App/SettingsView.swift`, `App/NotchHeaderView.swift`, `App/NotchPanelController.swift`, `App/PresentationCoordinator.swift`, `App/PreviewRenderer.swift`. Add `App/FullRowDisclosureStyle.swift`, register in `LimitRoom.xcodeproj/project.pbxproj`.

**Interfaces:** `MenuBarIndicatorImage(model:)` supplies a single SwiftUI Image label from a pure reading; `FullRowDisclosureStyle` implements DisclosureGroupStyle. Existing DashboardView/AppModel signatures stay compatible.

- [x] Capture original native indicator output through temporary demo-only PreviewRenderer diagnostics; capture NSPanel levels before/after `isFloatingPanel`.
- [x] Extract immutable compact reading, render the same content to a template NSImage and use it in MenuBarExtra and preview. Render with `ImageRenderer`, `.fixedSize()`, black foreground, 18-point height, scale 2; set `image.isTemplate = true`.
- [x] Full row action: `Button { configuration.isExpanded.toggle() } label: { HStack { chevron; configuration.label; Spacer() }.frame(maxWidth: .infinity).contentShape(Rectangle()) }`; add hover/AX value/reduce-motion support to both disclosures.
- [x] Remove reset icons, set panel floating property before `panel.level = .init(rawValue: NSWindow.Level.statusBar.rawValue + 1)`, add `.stationary`, remove unconditional Space hide and reconcile now plus after settlement.
- [x] Switch both opening and Settings haptics from `.alignment` to `.levelChange` with `.now`; keep user-only gating and 800 ms cooldown.
- [x] Run `swift build --disable-sandbox --cache-path build/SwiftCache` with module caches in `/private/tmp`. Expected: successful build. Repeat native diagnostics and existing renders, then remove temporary diagnostics. Manual desktop checks remain explicitly unverified.
- [x] Commit presentation repair locally.

### Task 2: Explicit Cursor.app connection

**Files:** Add `Sources/AllowanceConnectors/CursorLocalSession.swift`, `CursorLocalConnector.swift`; modify `CursorProjection.swift`, `Package.swift` (CSQLite connector dependency), `App/AppModel.swift`, `App/SettingsView.swift`, `App/CursorSignIn.swift`.

**Interfaces:** `CursorLocalConnector.read() async -> AgentSnapshot`, `reset()`, sanitized `CursorLocalConnectionIssue?`; AppModel `cursorUsesLocalSession`, `cursorConnecting`, `connectLocalCursor() async`, current disconnect path. Session material stays internal and is never Codable/exportable.

- [x] Implement bounded SQLite single-key read with `SQLITE_OPEN_READONLY`, explicit Unix VFS/`readonly_shm=1`, query-only, busy timeout, TEXT/BLOB decoding; do not copy DB. Immutable mode only without WAL/SHM. Reject missing/invalid/expired JWT and malformed ASCII subject/header bytes.
- [x] Use ephemeral URLSession, `httpShouldSetCookies = false`, nil cookie/cache/credential stores and redirect delegate returning nil. Two fixed GETs, <=64 KiB each and <=12 seconds, no raw errors surfaced. Validate same subject and reread session before accepting.
- [x] Preserve scope/time on same-account transient stale data; clear on auth/account change, never persist tokens. Project explicit individual plan/overall data only.
- [x] Add confirmation and explicit source switch. `configurationGeneration += 1` before switch/disconnect; clear reader/current snapshot then refresh. Never resume local reader for legacy web consent alone. Remove account-ambiguous stale cache when disconnected.
- [x] Run full Swift build and inspect source boundaries/Swift concurrency diagnostics. Expected: successful build with no token logging/storage/redirect path. No live Cursor credential probe without separate user opt-in.
- [x] Commit connector/UI/documented trust boundary locally.

### Task 3: Package and review

**Files:** `Config/App-Info.plist`, `Config/Widget-Info.plist`, `README.md`, `docs/architecture.md`, `docs/adr/0001-local-first-allowance-readings.md`, `docs/verification.md`, `docs/implementation-progress.md`.

**Interfaces:** Existing `Scripts/build-app.sh Release` generates `build/LimitRoom.app`, universal main/helper and ad-hoc signature.

- [x] Set version 0.4.1 (5); document changes, local-auth consent and manual verification gaps.
- [x] Run `swift format lint --recursive Package.swift App Sources Widgets Scripts/generate-icon.swift`, `plutil -lint Config/App-Info.plist Config/Widget-Info.plist LimitRoom.xcodeproj/project.pbxproj`, `bash -n Scripts/build-app.sh`. Expected: no errors.
- [x] Run `bash Scripts/build-app.sh Release`, `codesign --verify --deep --strict build/LimitRoom.app` and `lipo -archs` for main/helper. Expected: successful Release, valid ad-hoc signature, arm64+x86_64.
- [x] Render menu/notch/settings/native indicator using existing demo preview surfaces in RU/EN; record observations without claiming actual pointer/Spaces or live Cursor success.
- [x] Commit, obtain one fresh whole-increment review, address important issues and rerun affected checks. No remote action.
- [x] Hand off local app path and exact remaining manual checks.
