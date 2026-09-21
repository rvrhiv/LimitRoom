# Native indicator fixes and Cursor app connection

## Intent and scope

Fix the reported 0.4 UI defects without changing the approved card design: every disclosure header is a full-width button, the real menu bar shows the configured icon/ring/percentage, reset labels have no decorative clock/refresh icon, and the notch stays in place across ordinary Spaces. Add an explicitly enabled connection to the account signed in to Cursor.app. One account per agent, RU/EN, macOS 14+, local history and no LimitRoom backend remain unchanged.

The user previously requested saving documents and implementing without additional approval gates. This increment stays in the existing `feat/native-foundation` checkout. No push, installed-app replacement, live credential reads or Claude configuration changes are part of development verification.

## Findings and alternatives

- `DisclosureGroup` uses the default macOS disclosure hit target. Both subscription details and manual Claude setup need the same full-width accessible button style.
- The MenuBarExtra label receives arbitrary SwiftUI shapes. A normal NSHostingView preview does not validate this native label. Render the entire existing indicator as one template NSImage and pass an Image to MenuBarExtra. This retains native popup behavior and avoids introducing an NSStatusItem/NSPopover owner just for label drawing. Use the same image in Settings previews.
- `activeSpaceDidChange` explicitly orders out the notch before a 250 ms reconciliation. Keep an unchanged panel alive and stationary across ordinary Spaces. Preserve the current full-screen/sleep/session suppression policy.
- A native invisible NSPanel probe on macOS 26.6.2 reproduces the layering cause: assigning level 26 then `isFloatingPanel = true` resets level to 3. Set the floating flag first and the intended level last. No screen-saver/security-UI level and no private APIs.
- Cursor's current embedded web sign-in is unreliable for this user; its specific SSO failure has not been captured. CodexBar supports reading Cursor.app's `cursorAuth/accessToken` and deriving a first-party dashboard session. Use that narrowly scoped alternative, not browser-cookie import or a Teams admin API.

## Presentation implementation

One shared DisclosureGroupStyle supplies a full-width Button containing chevron, label and spacer, rectangular hit shape, hover feedback, pointing-hand cursor and expanded/collapsed accessibility value. Content remains keyboard accessible and honors Reduce Motion.

A value-only indicator reading separates observed model state from drawing. A template NSImage contains every selected component, preserves stale/missing markers and adapts to native menu-bar contrast. Its size is measured from content and generated at Retina scale. No continuous animation, TimelineView or 30 fps polling in the menu label. Keep current 30-second display clock and component preferences.

Remove icons from reset-time text in both quota cards and notch reset slots. Do not remove the independent stale/missing indicator attached to quota readings.

Space notifications reconcile visibility without unconditional hide; a delayed reconciliation checks settled fullscreen geometry without discarding current state. Collection behavior adds stationary participation. Hide/reset still happens for unavailable screens, sleep, inactive session, fullscreen or explicit mode switch.

Follow-up: the supplied screenshot confirms Zoom's status icon is above the expanded 0.4.0 panel. The user also requests stronger opening haptics. Change the native pattern from alignment to levelChange, perform immediately on genuine user-open only, preserve the 800 ms cooldown/disable switch, and use the same pattern in Settings preview. macOS provides patterns, not an amplitude control; final perceived strength depends on the trackpad.

## Cursor data and credential boundary

New primary button: **Connect installed Cursor…**. A confirmation explains exactly what is accessed: only `cursorAuth/accessToken` in `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`, read-only; no chats/projects, browser profiles or Keychain. Opt-in is persisted separately from the legacy web-login flag; existing users are not silently migrated. Keep separate web sign-in as an explicit alternative, never an automatic fallback between accounts.

An AllowanceConnectors actor owns the local connection. SQLite reads one bounded row, supports TEXT / UTF-8 and ASCII UTF-16LE BLOBs, uses read-only mode with live WAL when available, and immutable mode only when both sidecars are absent. Explicit Unix VFS plus `readonly_shm=1` prevents the ordinary read-only connection from creating or writing SHM; a runtime SQLite floor also guarantees NOFOLLOW support. Missing/incompatible storage fails closed without a less-safe retry. Never writes Cursor settings or refreshes its token. JWT is syntax/expiry/subject-checked for safe header construction, not treated as cryptographically verified identity. Expired credentials require signing in within Cursor.

The ephemeral HTTPS client sends the derived session only to fixed `https://cursor.com/api/usage-summary` and `/api/auth/me` paths. No redirects, cookies store, URL cache, credential store or token persistence/logging. Bound response sizes and timeouts. The server identity must match the token subject; reread the local session before accepting a result so a changed account cannot publish an old reading. Fail closed on auth/account changes, retain a same-account previous measurement with its original timestamp only for transient transport errors.

Project usage through CursorProjection. Use only `individualUsage`, never team totals. Preserve Cursor Models / Other Models / Total identifiers; derive Total only from an explicit positive plan limit when no total percentage exists. A separately labelled personal spending cap may use `individualUsage.overall` when present and enabled; do not relabel it as included quota. Missing is not zero or unlimited. Stable account scope remains server-derived and account histories stay separate.

Disconnect disables reads immediately, invalidates pending results, clears current Cursor cached state, retains history and leaves Cursor.app signed in. Reconnecting or selecting the web source explicitly invalidates the other reader, including its status-message callback, not just its quota result.

## Verification and limitations

User instructions prohibit new tests without an assigned test-case ID; none exists. Do not create test targets or assertion harnesses. Run existing builds, formatting, plist/shell checks and own-view renderers, and use temporary own-app diagnostics for native status-item image/NSPanel levels. Diagnostics are not an automated regression suite.

Before: record the real NSPanel level reset and native MenuBarExtra label output. After: repeat the same native probes and render both languages/component settings, build universal Release and verify ad-hoc signature. Actual Spaces transitions, pointer hit areas and live Cursor data remain manual acceptance checks unless observed during this run. Never claim an offscreen render proves desktop integration or a successful real-account connection.

## Research

- [CodexBar Cursor provider](https://github.com/steipete/CodexBar/blob/main/docs/cursor.md)
- [CodexBar CursorAppAuth implementation](https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Cursor/CursorAppAuth.swift)
- [Cursor dashboard response models](https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift)
- [Cursor billing and included-usage resets](https://cursor.com/help/account-and-billing/billing)
- [SQLite 3.22 Unix VFS read-only SHM implementation](https://github.com/sqlite/sqlite/blob/version-3.22.0/src/os_unix.c)

Research checked 2026-09-21. Cursor endpoints and local storage are private compatibility surfaces, not an official API guarantee. Implement independently; no third-party code or browser-cookie library is copied.
