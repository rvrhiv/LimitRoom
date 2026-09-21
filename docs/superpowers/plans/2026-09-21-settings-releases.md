# Clear settings and signed releases implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline; one fresh final reviewer. Steps use checkbox syntax. Independent privacy audit is read-only.

**Goal:** Deliver the requested UI fixes and safe GitHub distribution/update flow.

**Architecture:** Separate settings navigation from agent connection controls and display controls. Keep native notch geometry authoritative. Isolate Sparkle in a MainActor UpdateController and custom user driver; only the release tooling handles signing material.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Sparkle 2.10.0, Xcode/SwiftPM, GitHub CLI/Actions, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-09-21-settings-releases-design.md`

## Global Constraints

- Existing preferences, RU/EN, three agents and one account per agent remain.
- No new tests without an assigned test-case ID; none supplied. Builds/renderers/diagnostics are not regression tests.
- No live agent credential reads, installed-app replacement or security bypasses.
- Only sanitized snapshot history may be published. Existing local branches remain private.
- No silent update installation; only explicit selected-version approval. Missing signing configuration fails closed.

## Review Focus

- Rapid notch animation reversal and hidden/asymmetric sides must not shift physical camera coordinates or reflow header text.
- Settings refactoring must retain connection consent, account separation, disconnect and all preference bindings.
- Scheduled update discovery must not download/install/relaunch without explicit version approval; callbacks must clear stale authorization.
- Malformed/untrusted feeds, wrong signatures, unavailable signing keys and demo mode must not bypass integrity checks.
- Public tree/history/assets must exclude credentials, personal metadata and build artifacts; CI must not print secrets or run on untrusted PR code with signing keys.

### Task 1: Settings, Cursor mark and stable header

**Files:** `App/SettingsView.swift`, new `AgentSettingsView.swift`, `App/PresentationSettingsView.swift`, `ApplicationWindows.swift`, `AppModel.swift`, `DashboardView.swift`, `AgentIcon.swift`, `NotchRootView.swift`, `NotchHeaderView.swift`, `NotchPanelController.swift`, `PreviewRenderer.swift`, Xcode source list, `THIRD_PARTY_NOTICES.md`.

**Interfaces:** SettingsPage cases appearance/agents/notifications/general/updates; AppModel.settingsPage selects a page. SettingsView(model:) remains compatible. Existing connector actions and presentation preferences unchanged.

- [ ] Capture own-view opening geometry/frames in demo before changes; no desktop/other-window capture or new assertion harness.
- [ ] Transcribe the official cube filled path into a SwiftUI Shape, preserve geometry and add attribution.
- [ ] Split sidebar shell and agent content; default Appearance; full-width navigation buttons and native grouped sections. Move advanced fields behind secondary controls, keep every existing action.
- [ ] Replace compact Settings form with preview/mode/summary and full-window action. Agent buttons route to Agents.
- [ ] Fix only the diagnosed motion coupling: atomic native frame plus camera offset, no implicit animation of the header, stable text content width. Repeat own-view diagnostics and document limits.
- [ ] Run Swift build and Swift format; render RU/EN settings, agent page and compact panel. Expected: build/lint success, readable pages without horizontal clipping. Commit locally.

### Task 2: Verified, one-click updates

**Files:** new `App/UpdateController.swift`, `UpdateUserDriver.swift`, `UpdateSettingsView.swift`; `AppModel.swift`, `LimitRoomApp.swift`, `DashboardView.swift`, `SettingsView.swift`, `Package.swift`, Xcode project, `Config/App-Info.plist`, `Scripts/build-app.sh`.

**Interfaces:** `UpdateController(isDemo:)`, `start()`, `check()`, `install()`, `cancel()`, observable status/availableVersion/progress/automaticChecks. AppModel.updates supplies the same controller to every surface. SPUUserDriver maps progress and guarded install replies into that controller.

- [ ] Pin Sparkle exact 2.10.0 in SwiftPM and Xcode, embed framework preserving symlinks/executables, update local packaging to include framework and verify nested signatures.
- [ ] Read feed/public key from bundle; require HTTPS official release channel, decoded 32-byte Ed25519 key, signed feed and pre-extraction archive validation. Demo/unconfigured starts no updater/network.
- [ ] Use `SPUUpdater(hostBundle:applicationBundle:userDriver:delegate:)`; `checkForUpdateInformation()` for explicit checks; scheduled discovery dismisses offer after recording version. Install stores the selected version then calls `checkForUpdates()`; driver replies `.install` only for that version and permitted item, `.dismiss` otherwise. Clear approval on every terminal/cancel path.
- [ ] Display version badge and compact button, separate available/check/download/install/error states, last-check time, cancel and automatic-check setting. No profile telemetry. Preserve native auth prompts.
- [ ] Build both paths and render demo update states via existing renderer only. Expected: successful linkage/embedding, no update network in demo, explicit unconfigured state until signing setup. Commit.

### Task 3: Privacy-safe release channel and handoff

**Files:** `.gitignore`, `README.md`, `docs/adr/0002-signed-github-release-updates.md`, new release/privacy docs, release scripts/workflow, Config version/key, project/package lock files.

**Interfaces:** universal `build/LimitRoom.app`; signed ZIP and signed `appcast.xml` assets, GitHub `rvrhiv/LimitRoom`, sanitized initial `main` only.

- [ ] Remove personal checkout path; add targeted credential/runtime/private-key ignores; document audit scope/limitations without private values. Keep historical development claims clearly dated.
- [ ] Authenticate official downloaded GitHub CLI through user-confirmed browser device flow; verify current account/repository empty state. No global Git credential configuration.
- [ ] Configure dedicated Sparkle signing key only with appropriate user approval; embed public key and keep private material out of source. Scripts verify version/build/signatures and sign feeds/archives before publication. Never publish unsigned feed as enabled.
- [ ] Provide minimal CI build/check workflow and manual GitHub Actions release workflow for trusted collaborators on main. Use the approved environment signing secret with a local Keychain backup; PR builds cannot access it. Document collaborator release steps. Release version 0.5.0 (6), unless an existing remote release requires a higher version.
- [ ] Run SwiftPM, universal Release, format, plist, shell, deep strict signature, architectures and final privacy checks. Obtain one fresh review; fix important issues in one pass and observe remote-approval gate after review fixes.
- [ ] Publish only sanitized root commit using verified noreply identity, verify remote tree, then public visibility. Publish signed release assets only when all prerequisites are present. If auth/signing approval is missing, report exact blocker rather than claiming publication.
- [ ] Hand off local app, release/repository URLs when verified and exact manual checks. No installed-app mutation.
