# Notch Polish and Claude Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline, followed by one fresh whole-change reviewer. Steps use checkboxes. The user's existing no-additional-approval instruction overrides intermediate document gates.

**Goal:** Ship locally configurable circular indicators, polished native notch chrome, and explicit reversible Claude setup.

**Architecture:** Shared presentation values/renderers; one existing model and AppKit panel. A separate configuration installer complements, but never changes, the read-only connector boundary.

**Tech Stack:** Swift 6, SwiftUI, AppKit, macOS 14; no added dependencies.

**Spec:** `docs/superpowers/specs/2026-09-21-notch-polish-design.md` and `docs/superpowers/specs/2026-09-21-claude-setup-design.md`.

## Global Constraints

- Local existing feature checkout; no push, install, real Claude settings edits or publication during development.
- No new tests without assigned IDs. Builds/renders are checks, not regression tests.
- Preserve demo isolation, one pinned quota, account separation, freshness and RU/EN copy.
- Default wing width 88 pt; ordinary range 56...120 step 8, retain legacy larger saved values.
- No extra collapsed spacing. Expanded insets 22 pt horizontal, 12 pt top/bottom.
- Release 0.4.0 (4), universal, ad-hoc signed; installed copy untouched.

## Review Focus

- Missing/empty component preferences, all-off wings, legacy widths and 100%/stale indicators must stay reachable and legible.
- Layering must beat status items without covering native menus, secure overlays or changing fullscreen policy.
- Malformed/large/symlink settings and concurrent edits must not damage another application's configuration.
- Existing statusLine, repeated setup, failure between receipt/settings writes, disconnect and account rotation must preserve prior behavior and scope isolation.
- Demo/build/asset routes must match production visuals while never writing preferences or configuring Claude.

### Task 1: Circular indicator and native presentation

**Files:** `App/AgentIcon.swift` (create), `App/CompactIndicatorView.swift`, `App/PresentationPreferences.swift`, `App/NotchHeaderView.swift`, `App/PresentationSettingsView.swift`, `App/DashboardView.swift`, `App/NotchRootView.swift`, `App/NotchSilhouette.swift`, `App/NotchPanelController.swift`, agent-icon consumers, `App/PreviewRenderer.swift`, Xcode source membership.

**Interfaces:** Consume `AppModel.pinned/selection/displayDate`; produce `IndicatorComponents: Codable, Equatable` with `icon/ring/percentage`, and `AgentIcon(agent:size:)`. Each render receives an optional component override.

- [ ] Baseline SwiftPM build, then inspect existing renders/source. Expected: compile success; native seam remains unverified without screen evidence.
- [ ] Add the shared component value and independent persisted menu/left/right preferences; normalize the menu's all-off value to a visible ring. Keep the old percentage key for migration. Use `Circle().trim(from: 0, to: remaining / 100).rotationEffect(.degrees(-90))` with a dim full track.
- [ ] Add the official monochrome Blossom UI path and use `AgentIcon(agent: snapshot.agent, size: 16)` in cards, history and settings.
- [ ] Share controls/previews, retain slot types, 88 pt reset, scale all requested components together in narrow wings; stale/missing/DEMO never masquerade as live readings.
- [ ] Use outward circular shoulders with a constant black backing; disable native shadow. Set `NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)` below pop-up menus. Add full-target pointing-hand cursor lifecycle and expanded content padding.
- [ ] Update renderer for component switches and width range; run `swift build --disable-sandbox --cache-path build/SwiftCache` with existing module-cache env overrides, `swift format lint --recursive App Sources`, and `git diff --check`. Expected: success after formatting. Commit local presentation changes.

### Task 2: Reversible Claude setup

**Files:** Create `Sources/AllowanceConnectors/ClaudeSetup.swift`; modify `Sources/ClaudeBridge/main.swift`, `App/AppModel.swift`, `App/SettingsView.swift`, `App/DashboardView.swift`, `App/AgentCard.swift`.

**Interfaces:** `ClaudeSetup(settingsURL:directory:helperURL:)` exposes `install(scope:) throws`, `uninstall() throws`, and `isInstalled(scope:) -> Bool`; AppModel exposes `connectClaude()`, `disconnectClaude()`, `claudeMessage`, `claudeConnecting`. Bridge accepts `--previous-settings <backup>` alongside immutable `--scope`.

- [ ] Inspect existing store/scope and official statusLine contract; no raw settings or credentials in output.
- [ ] Implement private backup/receipt/helper staging, strict JSON/command validation, compare-before-replace, atomic write and exact managed-command matching. Preserve unrelated settings and previous statusLine output. Do not recursively wrap an old LimitRoom invocation.
- [ ] Refactor bridge collection into a throwing function so every exit path can still forward the already configured previous command with the same in-memory input; no raw input files or logs.
- [ ] Wire Connect directly from the Claude card and settings, configured/waiting feedback, safe disconnect, account reconnect and documented override/activity limitations. Disable mutations in demo and while busy.
- [ ] Run the full SwiftPM build, formatter and whitespace checks. Expected: success; no claim of live Claude validation. Commit locally.

### Task 3: Release, visual inspection and review

**Files:** Version plists/identity fallback, verification/progress/architecture docs, packaging only as necessary.

**Interfaces:** Consume Tasks 1–2; produce `build/LimitRoom.app` and synthetic images.

- [ ] Bump 0.4.0 (4); run `bash Scripts/build-app.sh Release`. Expected: universal app/helper, local output only.
- [ ] Run `codesign --verify --deep --strict`, both `lipo -archs`, `plutil -lint` for project/plists, shell syntax and full Swift format lint. Expected: valid.
- [ ] Render and inspect RU/EN/light/dark dashboard, expanded notch, 56/88/120/legacy160 wings, reset/hidden and independent components. No new test files. Record actual evidence and physical-screen/live-Claude gaps.
- [ ] Commit; obtain one fresh whole-increment review against both specs and Review Focus. Fix Important/Critical findings in one pass and rebuild relevant artifacts, no new tests without IDs. Keep minor deferrals explicit.
