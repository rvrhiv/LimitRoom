# Architecture

LimitRoom is a local-first macOS app built with Swift 6, SwiftUI, and AppKit. It supports Codex, Claude Code, and Cursor, with one active account per agent. The app owns collection and presentation; there is no LimitRoom backend.

## Module boundaries

| Module | Responsibility | Depends on |
| --- | --- | --- |
| `AllowanceCore` | Sendable value types, freshness, selections, trend calculations | Foundation |
| `AllowanceConnectors` | Agent-specific reads, normalization, explicit Claude setup | Core, system SQLite |
| `AllowanceStorage` | SQLite history, retention, export, latest-reading cache | Core, system SQLite |
| `AllowanceRuntime` | Concurrent collection, request coalescing, history coordination | Core, Connectors, Storage |
| `App` | Composition, SwiftUI views, native windows, WebKit, platform settings, updates | All modules, Sparkle |
| `ClaudeBridge` | Project status-line input into a quota-only local reading | Core |

`Package.swift` defines the modules. Xcode packages the app and bridge as separate targets. Only the app composes the full dependency graph; SwiftUI, AppKit, WebKit, and Sparkle stay out of Core.

## Domain and data flow

A connector returns an `AgentSnapshot`: an account scope, source state, optional subscription facts, and allowance windows. The monitor coordinates reads; the storage actor records eligible observations; `AppModel` supplies the resulting state to every view.

- **Account scope** separates subscriptions and their histories. Personal and team pools are not interchangeable.
- **Allowance window** is one independently resetting limit. Its stable ID matters more than its display title.
- **Reading** distinguishes source observation time (`observedAt`) from the time LimitRoom fetched it (`fetchedAt`).
- **Pinned window** is an agent + window ID, shared by both presentation modes. Selecting a chart window or holding the panel open is a separate action.

Keep these invariants:

1. Unknown, unsupported, signed-out, and stale are not zero or unlimited. A reset deadline alone does not prove a return to 100%.
2. Missing pinned windows stay selected but unavailable; never silently substitute another quota.
3. Account or source changes invalidate in-flight results and related notifications. An old callback must not restore a previous account's state.
4. Cache reuse requires the same confirmed account. Cursor's disk cache is not shown before current identity is verified.
5. Credentials, conversations, email addresses, and workspace paths do not enter history or exports. Setup backups are private recovery data, not diagnostics.
6. Demo mode uses synthetic data without collectors, personal persistence, agent configuration changes, notifications, launch-at-login changes, or update requests.

## Connector boundaries

### Codex

Run the installed official CLI's App Server over private stdio. Read account, rate-limit, and optional account-token-usage methods only; do not create conversations or copy authentication files. Prefer named rate-limit buckets, with the legacy response as a fallback. An explicitly configured invalid CLI path must fail clearly rather than select another binary.

[`account/usage/read`](https://learn.chatgpt.com/docs/app-server#7-token-usage-chatgpt) provides account-wide daily token counts and an optional lifetime total. Its failure does not invalidate a successful quota read. Bound the request, validate counts and unique calendar dates, and confirm account identity again before publishing token data. Keep missing days distinct from zero and retain provider day labels without timezone rebucketing. Token statistics are memory-only and fetched with quotas; they are not copied into SQLite, the latest-reading cache, or quota exports. Unsupported versions/accounts show unavailable statistics, never a fabricated total.

### Claude Code

An explicit, reversible setup service installs a status-line bridge. It preserves the previous command, private backups, and a recovery receipt; it detects conflicting settings edits before atomic replacement. Collection itself only reads the quota projection. The bridge never follows `transcript_path`.

Scope is fixed for each bridge invocation. Replayed or regressing input must not manufacture fresh observations. Claude does not supply reliable account identity here, so the user explicitly rotates the local scope after changing accounts. GUI environment inheritance and project-level status-line overrides can affect setup.

### Cursor

Local-session access requires separate consent. Read only the authentication record in Cursor's SQLite store, with read-only WAL/SHM handling and no writable fallback. Keep the session in memory; do not refresh it or persist it in LimitRoom.

Only fixed HTTPS usage and identity endpoints on `cursor.com` may receive that session. Reject redirects, bound response size and time, match server identity, and recheck the local account before publishing a result. Authorization, identity, or response-format failures invalidate readings.

The isolated WebKit sign-in is an explicitly selected alternative, not an automatic fallback. It never imports another app's cookies. Project personal usage only; neither team Admin APIs nor averages of unrelated percentages represent a personal allowance. This private dashboard contract remains experimental.

## History and scheduling

SQLite has one writer actor, versioned transactional migrations, and 90-day retention. Deduplicate observations by agent, account, window, and source time.

Quota charts show **remaining allowance on a fixed 0–100% scale**, calculated from existing observations as `clamp(100 − usedPercent, 0, 100)`. No database migration is needed. Chart selection is independent of the pinned window and limited to the currently confirmed account.

Connect only observations of the same account, window, plan, and known cycle. A gap longer than the greater of 10 minutes or 1.5 times the configured refresh interval breaks continuity, as do replenishment and corrections. Unknown cycles remain individual observations. Mark a new cycle only after the previous reset deadline passed; never invent a 100% observation. Cache the grouped history projection and use time-bucket extrema plus cycle markers for dense chart rendering, retaining original segment IDs so gaps cannot be joined. Hover values use the complete actual observations. Quota fractions do not measure tokens, cost, or model efficiency.

Quota refresh preferences are 1, 5, 30, or 60 minutes, defaulting to 5. One model-owned 30-second display clock checks whether collection is due; manual refresh and wake use the same coalescing and rate guards. Changing preferences must not create another timer. App-update checks are independent.

## Native presentation

`AppModel` owns data and selection. `PresentationCoordinator` chooses the host, while `ApplicationWindows` reuses settings and history windows. The menu bar and notch share agent cards and indicator components.

- The menu-bar label is one template image. Keep its preview on the same rendering path; a `TimelineView` in this label previously caused a redraw loop.
- One nonactivating AppKit panel integrates the notch and both wings. The camera area has no controls; all hover monitors are event-driven and removed on teardown.
- Set the panel level **after** `isFloatingPanel`: AppKit otherwise resets it. It sits above status items but below native pop-up menus.
- Animate native geometry and camera-relative offsets together; keep header content identity and width stable. Avoid a second implicit animation that makes text jump.
- Preserve the user's preferred mode through temporary menu-bar fallback. Ordinary Space changes reconcile visibility, not unconditionally destroy and recreate the panel.
- Opening settings closes the expanded notch and its temporary hold. Fullscreen, sleep, inactive-session, and unavailable-display policies remain in effect.
- Interactive rows have full hit areas, hover feedback, keyboard/accessibility labels, and English/Russian copy. Respect Reduce Motion; haptics are optional and device-dependent.

## Updates and extension

Sparkle is isolated in the App layer, separate from agent authentication. Discovery announces a version; installation needs an explicit user action. Require the signed feed and archive verification before extraction. Signing authority, recovery, and publication are documented in [Releasing](releasing.md).

To add an agent:

1. Establish a permitted source and define its account, window, reset, and failure semantics.
2. Implement normalization behind `AllowanceConnector`; keep secrets inside that boundary.
3. Register the agent in the app's composition and reuse the shared card, selection, history, and settings patterns.
4. Add truthful setup copy, EN/RU strings, and synthetic demo data. Update source/mark attribution when needed.
5. Verify account switches, missing data, stale reads, resets, and cancellation using the [contribution checklist](../CONTRIBUTING.md#verification). Keep live-source verification distinct from demo rendering.

Add agents only when requested; placeholder screens are not part of the current product.
