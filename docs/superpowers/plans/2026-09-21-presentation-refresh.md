# Presentation Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. User authorized implementation without intermediate approvals; execute locally in the existing feature checkout and obtain a fresh whole-change review at the end.

**Goal:** Ship the approved LimitRoom cards, app icon, and optional native notch presentation with rounded shoulders, animation and haptics in a local Release app.

**Architecture:** A single AppModel continues to own collection, history and pinned-window selection. Shared SwiftUI content is hosted by MenuBarExtra and a native AppKit notch controller; presentation preferences and transient panel state are separate from quota state.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Charts, macOS 14, existing local Swift package; no added dependencies.

**Spec:** `docs/superpowers/specs/2026-09-21-presentation-refresh-design.md`

## Global Constraints

- macOS 14+, Swift 6, Universal arm64/x86_64, RU/EN.
- Codex, Claude Code and Cursor only; no changes to connectors, authorization, storage or analytics.
- One AgentID + WindowID selection drives both compact presentations.
- Menu bar is the default; show percentage and notch haptics default to enabled.
- No new tests without assigned test-case IDs; none are available. Run builds and manual/render checks instead; do not claim TDD or regression coverage.
- Demo must not write real preferences, collect provider data or emit notifications.
- Preserve the approved icon A; use Bundle metadata for the version. Release is 0.2.0 (2).
- Work locally; no push, PR, installation, credential changes or publication.

## Review Focus

- A pinned window temporarily disappears: preserve its identity, show unavailable, never silently select another window.
- Rapid pointer crossings and pin toggles: cancel delayed actions, emit haptics only once per real expansion and never let hover steal keyboard focus.
- Lid/monitor/Space/fullscreen changes: reset transient hold, keep preferred mode, and avoid hiding all access when a notched display is absent.
- Transparent camera/shoulder areas: menu items beside the physical cutout must remain clickable; collapsed windows must not retain the expanded hit rectangle.
- Demo/packaging/Swift 6 isolation: no persisted demo changes, no second collector, correct resources in both build routes, and no actor-unsafe native callbacks.

---

### Task 1: Shared presentation primitives and identity

**Files:**
- Create: `App/PresentationPreferences.swift`, `App/AppIdentity.swift`, `App/CompactIndicatorView.swift`, `Scripts/generate-icon.swift`, `Resources/LimitRoom.icns`.
- Modify: `App/AppModel.swift`, `App/LimitRoomApp.swift`, `Config/App-Info.plist`, `Package.swift`, `LimitRoom.xcodeproj/project.pbxproj`, `Scripts/build-app.sh`.

**Interfaces:**
- Consumes: `AppModel.selection`, `AppModel.pinned`, `AppModel.displayDate`, approved SVG geometry.
- Produces: `PresentationMode` (`menuBar`, `notch`); `@MainActor @Observable PresentationPreferences` with `mode`, `showPercentage`, `hapticsEnabled`, `onModeChange`; `AppModel.presentation`; `CompactIndicatorView(model: AppModel, showsWindowTitle: Bool)`; `AppIdentity.version`, `AppIdentity.build`; `AppIconView`.

- [ ] Read the existing model/init and record baseline build. Run:
  ```sh
  CLANG_MODULE_CACHE_PATH=/private/tmp/limitroom-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/limitroom-swift-cache swift build --disable-sandbox --cache-path build/SwiftCache --target LimitRoom
  ```
  Expected: build succeeds; user-cache warnings can be recorded separately.
- [ ] Add demo-safe preferences and the model-owned instance:
  ```swift
  enum PresentationMode: String, CaseIterable { case menuBar, notch }
  // Each preference persists only when !isDemo. Unknown saved modes use menuBar.
  // Changing mode invokes onModeChange; numerical display changes are observed by SwiftUI.
  ```
- [ ] Extract the existing half gauge; compose an agent glyph inside it, optional percentage and freshness. Missing pinned readings keep `selection?.agent` as identity and show a dash. Keep source percentages unchanged in the model.
- [ ] Render the approved vector geometry into a deterministic iconset using AppKit, compile with iconutil, include `.icns` as an Xcode resource and copy it in the local packager. Add `CFBundleIconFile`; bump version/build to 0.2.0/2. SwiftPM excludes the external Resources folder naturally.
- [ ] Run the build command above and `plutil -lint Config/App-Info.plist`; inspect icon output and resource configuration. Expected: successful compilation and valid plist, unchanged data modules.
- [ ] Commit only this task's files locally: `feat: add shared presentation identity and preferences`.

### Task 2: Approved dashboard, uniform cards and compact pages

**Files:**
- Create: `App/AgentCard.swift`, `App/HistorySummaryView.swift`, `App/PresentationSettingsView.swift`.
- Modify: `App/DashboardView.swift`, `App/SettingsView.swift`, `App/Localization.swift`, `LimitRoom.xcodeproj/project.pbxproj`.

**Interfaces:**
- Consumes: Task 1's preferences and identity; `AppModel.pin`, `rates`, `chartSelections`, `setChartWindow`, `refresh`, existing connection methods.
- Produces: `DashboardStyle` (`menuBar`, `notch`); `DashboardView(model:style:isHeld:toggleHold:close:openHistory:openSettings:)` with default menu arguments; `AgentCard(snapshot:selection:now:pin:connect:)`; `HistorySummaryView(model:openHistory:)`; `PresentationSettingsView(model:openSettings:)` (fallback message is observed through the shared preferences).

- [ ] Replace the large hero and mixed footer buttons with common header, segmented tabs, scrollable cards and version footer. Preserve onboarding and access to refresh/quit/settings/history.
  ```swift
  enum DashboardStyle { case menuBar, notch }
  // The notch host supplies close/hold callbacks. The menu host has no hold control.
  // Card selection calls model.pin(agent: snapshot.agent, window: window) only.
  ```
- [ ] Split AgentCard into its own file. Use the same header/window/details layout for all agents; selected agent border and exact-window radio are independent of details disclosure. Keep all existing optional subscription fields, reset dates and source timestamps. Empty states retain a visible setup action where meaningful.
- [ ] Add compact Charts content from `model.rates`, existing period selection and independent per-agent analytic window pickers. Add the shared display settings, supported-trackpad note and links to full connection settings.
- [ ] Run the Task 1 build command. Render the existing demo preview path and inspect card hierarchy, stale/unknown treatment in code, selection accessibility, footer and no overflow at 414-point width. Expected: compile success, uniform cards, no invented source fields.
- [ ] Commit locally: `feat: unify allowance cards and dashboard tabs`.

### Task 3: Native notch presentation and lifecycle

**Files:**
- Create: `App/NotchGeometry.swift`, `App/NotchSilhouette.swift`, `App/NotchPanelController.swift`, `App/NotchRootView.swift`, `App/PresentationCoordinator.swift`, `App/ApplicationWindows.swift`.
- Modify: `App/LimitRoomApp.swift`, `App/SettingsView.swift`, `LimitRoom.xcodeproj/project.pbxproj`.

**Interfaces:**
- Consumes: Tasks 1–2, the single AppModel, NSScreen safe-area geometry and NSWorkspace notifications.
- Produces: `PresentationCoordinator(model:)`, `start()`, `stop()`, `showsMenuBar`, `openHistory()`, `openSettings()`; `NotchPanelController(model:openHistory:openSettings:)`, `show(on:)`, `hide()`, `close()`; geometry from `NotchGeometry(screen:)`; transient observable `NotchPanelState`.

- [ ] Add pure geometry/silhouette code with rounded concave shoulders. Camera width is measured between auxiliary top areas. Compact interactive bounds are camera-width × 34 points; expanded content is 430 points wide and bounded by available screen height.
- [ ] Build a nonactivating interactive NSPanel below the menu area and a separate camera-only decoration window with `ignoresMouseEvents = true`. Do not enable fullScreenAuxiliary or global keyboard monitoring. Rounded background does not enlarge the compact hit target.
  ```swift
  // All native mutations are MainActor-isolated.
  // Hover tasks wait 220/360 ms, are cancelled on opposing transitions,
  // and recheck pointer position and current visibility before changing state.
  // Expansion changes frame from a fixed top-center anchor; Reduce Motion skips resizing animation.
  ```
- [ ] Add temporary pin, close/Escape and one rate-limited haptic call:
  ```swift
  NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
  ```
  Gate on actual user-initiated compact→expanded transition, enabled preference and 800 ms since the last pulse; never pulse on boot, data refresh or display restoration.
- [ ] Coordinate display/Space/sleep/active-app notifications, observable preferences and presentation options. Fall back to menu bar only when no valid built-in notch geometry exists; preserve the user's mode. Collapse/hide on fullscreen and transitions, return compact. Remove notification/event observers at shutdown. Share full settings/history windows across both hosts.
- [ ] Run the build command; inspect callback isolation, observer removal, hover-task cancellation, source singleton and compact frame. Native metadata diagnostics may inspect screen/window bounds only, without capture or persistence.
- [ ] Commit locally: `feat: add animated native notch presentation`.

### Task 4: Release verification, native previews and handoff

**Files:**
- Create: `App/PreviewRenderer.swift` if extraction keeps the delegate focused.
- Modify: existing demo render entry in `App/LimitRoomApp.swift`, `README.md`, `docs/architecture.md`, `docs/design/README.md`, `docs/interviews/2026-09-21-presentation-refresh.md`, `docs/verification.md`, `docs/implementation-progress.md`, `LimitRoom.xcodeproj/project.pbxproj` if a preview file is extracted.

**Interfaces:**
- Consumes: completed native UI and existing `--demo --render-preview <path>` entry.
- Produces: local `build/LimitRoom.app`, own-view light/dark and notch preview images, explicit verification report and no changes in `/Applications`.

- [ ] Extend the existing offscreen demo renderer to select menu/notch compact/notch expanded views; it must render only its own views and terminate. Preview mode must never collect providers or persist preferences.
- [ ] Run `bash Scripts/build-app.sh Release`. Expected: successful universal app with icon, version 0.2.0 (2), Claude helper.
- [ ] Run `codesign --verify --deep --strict build/LimitRoom.app`, `lipo -archs build/LimitRoom.app/Contents/MacOS/LimitRoom`, and plist/resource checks. Expected: valid ad-hoc signature, arm64 and x86_64, icon resource in the bundle.
- [ ] Render and visually inspect the native layouts in light/dark, menu/notch and compact/expanded configurations. Record any hardware interactions not exercised; do not claim trackpad or fullscreen validation from images.
- [ ] Run `git diff --check`, the package build and a fresh whole-change review. Fix important findings within scope, rerun relevant verification; do not add tests without IDs. Record minor deferrals and limitations.
- [ ] Update documentation, commit locally `docs: record native presentation verification`, and provide the app path. Do not overwrite or stop the installed copy, push commits or publish releases.
