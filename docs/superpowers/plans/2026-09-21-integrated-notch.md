# Integrated Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline, followed by one fresh whole-change reviewer. Continue without intermediate approval gates under the user's existing instruction.

**Goal:** Fix full-area dashboard tabs, add live display controls, and integrate a one-quota panel with the whole physical notch.

**Architecture:** One existing AppModel and selection; shared SwiftUI header/previews; persisted presentation preferences; a single top-anchored AppKit panel with event-driven hover.

**Tech Stack:** Swift 6, SwiftUI, AppKit, macOS 14, no new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-21-integrated-notch-design.md`

## Global Constraints

- Local existing `feat/native-foundation` checkout; no push, PR, install, provider/account mutations or publication.
- No new tests without assigned IDs (none supplied). Builds and own-view renders are verification, not regression tests.
- Preserve demo isolation, current collection/history, stable one-quota identity and RU/EN localization.
- One quota on both sides, defaults left quota/right reset; width 80...160 points, default 112.
- Keep existing pin, Reduce Motion, lifecycle fallback, no hover activation or global keyboard monitor.
- Release 0.3.0 (3), universal app, ad-hoc signature; installed copy remains untouched.

## Review Focus

- Hidden/asymmetric wings and width changes during animation: the camera stays physically aligned, the compact frame has no body below it, and expanded settings remain usable.
- Rapid pointer motion across the camera, drags, native menus and pin toggles: one delayed open, cancellable close, no focus stealing or repeated haptics; event monitors are cleaned up.
- Missing/stale quota, unknown/elapsed reset, same-duration Cursor categories and persisted invalid settings: display honest values without switching the selected quota or creating data.
- Display/lid/Space/fullscreen/mode changes and pointer already over the notch: preserve fallback, return compact, no spontaneous expansion and no inaccessible running app.
- Preview/build routes: same render primitives, no demo preference writes or collectors, correct Xcode membership and Swift 6 native callback isolation; tab hit rectangles include padding.

### Task 1: Tabs, configurable content and live previews

**Files:** Modify `App/DashboardView.swift`, `App/PresentationPreferences.swift`, `App/PresentationSettingsView.swift`, `App/SettingsView.swift`, `App/CompactIndicatorView.swift`, `LimitRoom.xcodeproj/project.pbxproj`; create `App/NotchHeaderView.swift`.

**Interfaces:**
- Consumes `AppModel.selection`, `pinned`, `displayDate`, `presentation`; existing indicator and dashboard.
- Produces `NotchSlotContent`, `ResetDisplayStyle`, left/right/reset/width preferences and `onLayoutChange`; `NotchHeaderView(model:cameraWidth:cameraLeading:height:)`; shared display controls take `model`.

- [ ] Baseline: run `CLANG_MODULE_CACHE_PATH=/private/tmp/limitroom-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/limitroom-swift-cache swift build --disable-sandbox --cache-path build/SwiftCache --target LimitRoom`. Expected: succeeds (user cache warnings allowed).
- [ ] Give tab labels full rectangular hit regions; add hover and press state with Reduce Motion support. Compare with existing full-width card selection buttons.
- [ ] Add demo-safe persisted choices and layout callback, sanitize side width. Render reset date from actual selected window `resetsAt`; preserve missing/stale state and source window names.
- [ ] Share header/slot primitives with live menu and notch previews in both settings surfaces; add explicit native feedback preview button and menu-space warning.
- [ ] Register new Swift file in Xcode; run the baseline build and `git diff --check`. Expected: compilation and whitespace checks succeed. Do not claim interactive hit testing from a build.
- [ ] Commit locally: `feat: add display previews and full-area dashboard tabs`.

### Task 2: Unified notch window and whole-camera hover

**Files:** Modify `App/NotchGeometry.swift`, `App/NotchRootView.swift`, `App/NotchSilhouette.swift`, `App/NotchPanelController.swift`, `App/PresentationCoordinator.swift`, `App/PreviewRenderer.swift`.

**Interfaces:**
- Consumes Task 1 preferences/header and `onLayoutChange`.
- Produces top-anchored `panelFrame(expanded:leftWidth:rightWidth:)`, shared physical-header state and `preferencesDidChange()`; removes separate camera backing window.

- [ ] Derive collapsed frame at screen top, camera-height tall, with independently resolved wing widths. Expanded body is bounded to available screen height, at least 430 points wide.
- [ ] Integrate camera-height header and dashboard in one silhouette; animate x/width/height while keeping the camera at its physical coordinate. Settings changes preserve pin/tab.
- [ ] Install local/global mouse monitors only while visible, covering camera and wings. Avoid restarting open delay on every movement, suppress opening during drag, keep native menu/pin close guards and local Escape.
- [ ] Preserve sleep/fullscreen/display fallback and teardown. Update preview renderer enough for the new root-state interface.
- [ ] Run the Task 1 build command and `git diff --check`. Expected: success; inspect monitor removal, cancellation, no hover key focus and no second model.
- [ ] Commit locally: `feat: integrate quota wings with the physical notch`.

### Task 3: Release, visual checks and handoff

**Files:** Modify `App/PreviewRenderer.swift`, `Config/App-Info.plist`, `docs/verification.md`, `docs/implementation-progress.md`, `docs/design/README.md`, `CONTEXT.md` as needed.

**Interfaces:**
- Consumes final native UI and existing synthetic offscreen renderer.
- Produces local Release app, updated own-view images, verification report and fresh review package.

- [ ] Extend existing renderer switches for new display layouts and exact/hidden reset previews; render the integrated header only once. Demo does not collect or persist.
- [ ] Bump version to 0.3.0/build 3. Run `bash Scripts/build-app.sh Release`. Expected: universal success, no installed app changes.
- [ ] Run `codesign --verify --deep --strict build/LimitRoom.app`, `lipo -archs` for main/helper, `plutil -lint` for plists/project, `bash -n Scripts/build-app.sh`, `swift format lint --recursive Package.swift App Sources Scripts/generate-icon.swift`. Expected: valid signature/plists/scripts/style and both architectures.
- [ ] Render and inspect light/dark menu, settings, compact/expanded notch, asymmetric wings, exact/hidden reset, without percentage. Expected: no duplicate camera, no below-camera compact content, no overlap; record limitations honestly.
- [ ] Run Task 1 build command and `git diff --check`, commit locally `feat: package integrated notch preview release`.
- [ ] Obtain fresh review of the whole increment; fix important findings in one pass within scope, rerun relevant builds/renders. No new tests without IDs. Record all rulings/deferred minors in verification docs and final handoff.
