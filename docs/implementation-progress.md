# LimitRoom implementation ledger

## Settings and app-update action 0.5.1 — 2026-09-22

- Bounded follow-up to the accepted design: settings accent and cleanup, saved 1/5/30/60-minute polling preference, collapse the notch on opening Settings, and a prominent version-labelled app-update button. User clarified that the button is for the GitHub app update, not quota readings.
- Removed obsolete extension implementation, targets and references throughout tracked source and docs without changing old Git commits or deleting local user data. Architecture stays Core → Storage/Connectors → Runtime → App.
- Continued inline in the established clean public-lineage checkout. No new design approval pause under the user's existing waiver; no new tests without assigned IDs.
- Prepared 0.5.1 (7), local universal app/archive and manual GitHub Actions instructions. Source push is authorized; Release dispatch, tags and publication are reserved for the user. No installed-app replacement or live-agent configuration changes.
- Local build/render/validation results and explicit native acceptance limits are recorded in `docs/verification.md`. Read-only review found no Critical or Important issues; both Minor documentation findings were corrected. The review does not establish native interaction, elapsed-time polling, live update replacement or Intel execution; those remain manual acceptance checks.

## Native indicator and Cursor.app — 2026-09-21

Plan: `docs/superpowers/plans/2026-09-21-native-indicator-cursor.md`; base `f72f170`.

- Task 1: `5140a8b` — native template indicator with shared preview, full-row disclosures, icon-free reset labels, corrected NSPanel property order, stationary Spaces reconciliation, stronger native haptic pattern. Native before/after button and NSPanel probes confirm both concrete causes; desktop interaction acceptance remains manual.
- Task 2: `9b3fceb` — opt-in local Cursor.app session reader, bounded SQLite/HTTPS, identity and generation guards, mutually exclusive web alternative, personal-only quota projection and connection messages. SwiftPM compilation and Settings preview verified; no real token/API read.
- Task 3: local universal Release 0.4.1 (5) built; ad-hoc signature, architectures, formatting, plist and shell checks verified. Fresh whole-increment review and one fix pass completed; post-fix SwiftPM/Release and all listed checks passed. Native interaction and live-account checks remain manual.
- Ruling: Continue inline in the established checkout under prior no-extra-approval direction; no remote or installed-app changes — cost: user reviews a local build, not a deployed update.
- Ruling: No new tests without IDs; builds/renderers/native diagnostic output only — cost: manual acceptance and lack of regression coverage are explicit.
- Ruling: Do not inspect live Cursor credentials during development; use the shipped opt-in flow — cost: real-account compatibility remains unverified.
- Ruling: Do not show a disk-cached Cursor value until current identity is validated — cost: offline startup shows unknown rather than a possibly different account.
- Final: Ruling: Re-grade the obsolete WebKit message callback from Minor to Important — an old sign-in result can contradict the newly selected source and recovery guidance — cost if wrong: one narrow callback-invalidation fix in the review pass.
- Final review: no Critical; the SQLite SHM write risk and message race were fixed together. Explicit Unix VFS/readonly_shm prohibit writable sidecar fallback; suspended WebKit sources lose their message callback. No new regression tests without IDs, no second reviewer, no newly deferred Minor findings. See `docs/verification.md` for evidence and boundaries.

## Notch polish and Claude setup — 2026-09-21

Plan: `docs/superpowers/plans/2026-09-21-notch-polish.md`; increment starts at `89247a8`.

- Task 1: `807e8ed` — attributed ChatGPT mark, configurable full rings, separate menu/left/right components, 88 pt default, outward shoulders, explicit black fill without native shadow, panel above status items, cursor and content padding. Existing renderer updated; SwiftPM/style/project checks pass.
- Task 2: `47d5e68` — explicit reversible setup service and card/settings actions; fixed account scope, private backups and helper copies, previous-command forwarding, interrupted-install receipt and installer lock. Both SwiftPM products compile; live setup was not performed.
- Task 3: local universal Release 0.4.0 (4), deep/strict signature/style/plist checks and synthetic own-view images verified. Native-screen and real-Claude acceptance is not claimed.
- Ruling: Continue in the existing requested feature checkout with the earlier document-approval waiver — preserves task continuity — cost: no extra checkout isolation or remote backup.
- Ruling: No new tests without assigned IDs — explicit user rule overrides TDD steps — cost: no automated behavioral regression proof.
- Ruling: Above status icons but below native pop-up menus; retain fullscreen/session hiding — keeps OS menus and secure overlays usable — cost: not literal coverage of every system surface.
- Ruling: User cancelled collapsed-gap change; no native seam screenshot supplied — change only explicit geometry/chrome requirements and keep native acceptance pending — cost: hardware-specific visual issues may remain.
- Final review of `89247a8..a4750fc`: no Critical, three Important, no Minor. One fix pass added a full reconnect guard, pre-commit serialized-size validation/compact fallback, and scope-first disconnect with recoverable managed-state detection. The durable scope marker is authoritative across restart. Fresh builds/lints/signature checks pass; no new tests without IDs and no second reviewer.
- Final: Ruling: Physical cutout/layering/full-target cursor require native acceptance — own-view renders cannot prove WindowServer behavior — cost: visual/interaction corrections may remain.
- Final: Ruling: Live Claude session compatibility and previous-command execution stay unverified — actual configuration was explicitly left untouched — cost: configuration/session-specific corrections may be needed.
- Final: Ruling: Earlier foundation, notarization and publication are outside this increment — preserve existing boundaries — cost: this is a local preview, not a validated public release.

## Integrated notch — 2026-09-21

Plan: `docs/superpowers/plans/2026-09-21-integrated-notch.md`; increment starts at `5786aa9`.

- User chose one selected quota shared by both notch wings. Defaults: left quota/right reset. Source/account/history contracts unchanged.
- Task 1: full-area tabs with hover/pressed feedback; demo-safe side/reset/width preferences; shared live display previews and explicit haptic preview control.
- Task 2: one top-anchored status-level nonactivating panel, physical camera inside its header, independent side widths, no collapsed protrusion. Event-driven whole-camera hover and cancellable frame transitions; layout changes preserve expanded state/tab/hold.
- Task 3: Release 0.3.0 (3), universal app/helper, deep strict ad-hoc signature, style/plist/script checks and own-view renders. Fixed percentage wrapping at 80 pt and duplicate native Slider label after visual inspection.
- Ruling: Continue inline in the existing checkout without new document approval gates — the user previously explicitly requested saved documents and uninterrupted implementation — cost if wrong: local changes require review/reversal, with no remote or installed-app effect.
- Ruling: Skip creation of new tests, including reproduction tests — user AGENTS requires assigned test-case IDs and none exist — cost: builds/renders and source review cannot prove interactive regression safety; hardware acceptance remains explicit.
- Final review: fresh read-only reviewer of `5786aa9..d9614a7` found no Critical errors and one Important compact-demo-label regression. Fixed with a marker in each visible demo wing, including reset/window-only; verified before/after via existing renderer and rerun SwiftPM/Release/signature/style checks. No second reviewer or new tests.
- Final: minor (deferred): exact-date reset after its deadline still shows the past timestamp plus a stale icon; explicit awaiting text is in the tooltip/accessibility only. Data is honest; a visible awaiting phrase can be refined later.
- Final: Ruling: Physical camera hover/focus, native picker tracking, haptic feel and rapid motion remain unverified — source/renders cannot establish those device interactions — cost if wrong: user testing may expose interaction-specific corrections.
- Final: Ruling: Spaces/fullscreen/Stage Manager, display/lid and accessibility traversal remain manual acceptance items — no interactive system transitions were exercised — cost if wrong: platform-specific visibility or navigation issues may remain.
- Final: Ruling: Leave live providers, history/storage, notarization and distribution outside this increment — these contracts were not changed and local UI packaging does not establish their readiness — cost if wrong: this is not a verified public release.

## Native foundation — 2026-09-20

Plan: `docs/superpowers/plans/2026-09-20-native-foundation.md`.

- 2026-09-20: Interview rechecked. One account per agent, RU/EN, no paid Apple membership confirmed.
- GitHub `rvrhiv/LimitRoom` exists and is private. Local origin configured. HTTPS Git authentication failed; SSH strict host verification also unavailable. No files pushed.
- Ruling: Assigned test-case IDs are absent. Follow user AGENTS.md: no new automated tests; compile and document manual checks. Cost: behavioral regression coverage remains incomplete.
- Ruling: Private releases do not enable public updating. Keep updater inactive until a reachable signed channel exists. Cost: first local builds update manually.
- Ruling: Cursor personal login is an experimental integration requiring live validation, not a guaranteed public API. Cost: automatic Cursor data can remain unavailable while the rest of the app works.
- Pre-flight: Core types are shared by storage/connectors/runtime; only the app links all modules. No secrets cross into history.
- Task 1: implemented; Core builds. Rates break across cycles/scopes/plans and long gaps. No automated behavioral tests without IDs.
- Task 2: implemented; SQLite actor, transactional schema, retention, export and cache. Actual Codex observation persisted.
- Task 3: implemented initial connectors; Codex live transport confirmed; Claude bridge has active-scope/replay guards; Cursor private endpoint projection + isolated WebKit transport implemented but live login unverified.
- Task 4: implemented baseline scheduler/coalescing, persisted last-known values, configuration generations, alert crossings and opt-in platform settings. Adaptive backoff and actual OS behaviors remain release follow-ups.
- Task 5: implemented RU/EN native overview/settings/history. Demo/light/dark rendered; live Codex app started. No full accessibility/permission-dialog audit claimed.
- Task 6: Xcode app/helper build Universal. Local ad-hoc app packaged. Installed-app behavior remains a separate manual acceptance check.
- Task 7: independent review findings fixed and narrowly rechecked; fresh builds and run evidence recorded in docs/verification.md. Implementation committed locally as `e734aa0`; remote publication remains blocked by Git authentication.
- Review ruling: Keep a conservative Claude baseline when fields regress, disappear or reset moves backwards. Tradeoff: an unchanged/corrected reading can remain stale until trustworthy progress/new cycle.
- Review ruling: Generation checks protect both UI replacement and notification side effects after asynchronous work; no source change may be undone by superseded reads.
- Runtime finding: TimelineView inside menu-bar label caused a native redraw loop. Replaced with model clock; subsequent launch completed and idle observation was 0.0% CPU.

## Presentation refresh — 2026-09-21

Plan: `docs/superpowers/plans/2026-09-21-presentation-refresh.md`.

- User approved design v3, icon A «Запас», native haptics, rounded notch shoulders and animated expansion. Explicitly waived intermediate spec/plan approvals.
- Continued in existing `feat/native-foundation` checkout from `c970847`; preserved earlier work and did not publish or change the installed app.
- Added demo-safe presentation preferences, shared half-gauge/agent glyph and Bundle identity. Packaged approved icon in both Xcode and local build routes.
- Replaced mixed quota layout with shared AgentCard, explicit window selectors, quotas/statistics/settings tabs and version footer. Full connection/history actions remain available.
- Added PresentationCoordinator, one shared owner of full windows, NSScreen-based geometry, a nonactivating panel and passive camera backing. Hover tasks and finite frame transitions are cancellable; hold is transient; haptics are user-triggered and rate-limited.
- Release `0.2.0 (2)` built Universal with a valid local ad-hoc signature. Own-view previews inspected in RU/EN and light/dark. Exact evidence and hardware-only limits are in `docs/verification.md`.
- No new tests without assigned IDs; no data-layer, connector, account, storage contract changes.
- Fresh whole-change review `c970847..add6ca7`: no confirmed Critical/Important issues; duration-only compact Cursor window names deferred as Minor. Full titles and selected identities remain correct.
- Ruling: Continue in the existing feature checkout rather than create a second worktree — it contains this task's approved design history — cost: no extra checkout isolation; unrelated work must remain intact.
- Ruling: Keep physical haptics and hover/focus unverified — own-view renders do not establish device interaction — cost: user testing may require follow-up adjustments.
- Ruling: Keep fullscreen/Spaces/Stage Manager/lid/menu auto-hide unverified — WindowServer transitions were not exercised — cost: hardware-specific corrections may be needed.
- Ruling: Keep pointer routing at transparent shoulders and animation boundaries unverified — frame separation is not an interaction check — cost: native edge hit targets may need adjustment.
- Ruling: Include minimized-window restoration, VoiceOver and keyboard traversal in the manual pass — no confirmed regression was found — cost: unexercised restoration/accessibility issues may remain.
- Ruling: Keep live provider validation, credentials and signed distribution outside this presentation increment — the contracts are unchanged — cost: local packaging is not a verified public release.
- Ruling: Preserve the local feature branch without merge/push or a new integration approval — user requested continuous local implementation — cost: no remote backup or integration is performed.
