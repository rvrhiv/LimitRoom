# Using LimitRoom

## Installation

Download the ZIP from the [latest release](https://github.com/rvrhiv/LimitRoom/releases/latest), quit any older instance, and move the extracted app to **Applications**. Put it in this stable location before enabling launch at login. Requirements: macOS 14+, Apple Silicon or Intel.

Current builds are ad-hoc signed, not Developer ID signed or notarized. macOS may say it cannot verify LimitRoom or check it for malicious software. If the ZIP came from this repository's releases and you trust the build:

1. Try opening **LimitRoom.app** from **Applications**. Dismiss the warning without moving the app to Trash.
2. In **System Settings → Privacy & Security**, scroll down and select **Open Anyway** for LimitRoom.
3. Choose **Open** in the confirmation; authenticate if requested.

This adds an exception for LimitRoom. Keep Gatekeeper and quarantine intact; do not bypass warnings about detected malware or a damaged app. See [Apple's first-launch guide](https://support.apple.com/en-us/102445). Building locally is another option: see [Contributing](../CONTRIBUTING.md#local-development).

Sparkle verifies app updates, but does not replace Apple's first-install security checks.

Open **Settings → Updates** to check for a newer version. When one is found, the panel shows an **Update LimitRoom** button. Installation is explicit and relaunches the app; automatic version checks can be disabled. These checks are independent of quota refresh.

## Connect your agents

### Codex

Use the official Codex CLI, already signed in to ChatGPT. LimitRoom reads the CLI's App Server; it does not run a coding task or copy authentication files. If detection fails, set the absolute CLI path in **Settings → Agents → Codex**.

The CLI must support App Server. Having only Codex Desktop is not enough to guarantee discovery. API-key billing is not treated as a ChatGPT subscription quota.

### Claude Code

1. Sign in to Claude Code, then choose **Connect** in its LimitRoom card or settings page.
2. Clicking **Connect** performs the reversible status-line setup: it backs up existing settings and preserves any previous command. There is no additional confirmation dialog.
3. Restart Claude Code, let it produce a response, then refresh LimitRoom. Quotas appear only if that Claude Code version and subscription provide them.

This configures quota collection, not account sign-in. Project settings can override the user status line. The actual settings path is shown in LimitRoom; a shell's `CLAUDE_CONFIG_DIR` may not reach a Finder-launched app. Unsupported or conflicting settings are not silently replaced; a manual setup command is available on the agent page.

After switching Claude accounts, use the account-change action in LimitRoom and restart Claude Code. This keeps histories separate; a manually installed command must be updated too. **Disconnect** restores the previous status-line setting while retaining unrelated current settings.

Claude sends quota observations through its active session. Repeated unchanged input may remain marked stale; polling the local file does not request a fresh quota from Anthropic.

### Cursor

Sign in to the installed Cursor app, then choose **Connect Cursor.app…** in LimitRoom and confirm access. LimitRoom reads the current session from Cursor's local store in read-only mode, then requests personal usage from Cursor. It does not derive quota from conversations.

The credential stays in memory and is sent only to fixed HTTPS endpoints on `cursor.com`. LimitRoom neither stores nor renews it. Renew an expired sign-in in Cursor itself; disconnecting LimitRoom leaves Cursor's own sign-in intact.

**Alternative sign-in** uses LimitRoom's separate WebKit profile. Some SSO providers do not support embedded browsers. Choose one source explicitly; LimitRoom does not import browser cookies or silently switch accounts.

Cursor's dashboard endpoints are private and may change. Personal and team pools are not interchangeable, and some fields may be unavailable. Compare readings with your Cursor dashboard before relying on them.

## Choose what stays visible

Select a quota row in an agent card to pin that exact window. Both presentation modes use this selection; browsing another card or the Statistics tab does not change it. Expand **Subscription and source** for the facts the agent actually reports.

Extra **Resets remaining** and **Resets used** appear there only when the source reports a count and the reading is fresh. Codex can report remaining resets; its current interface does not provide a complete used count. Claude Code and Cursor do not supply either count through their current connections, so those rows stay hidden. These are additional resets, not automatic quota renewals. LimitRoom does not spend them.

In **Settings → Appearance**:

- **Menu bar:** click the indicator to open the panel; choose the agent icon, ring, percentage, or a combination.
- **Near the camera:** hover over the notch to open all cards. Use the pin to keep the panel open after the pointer leaves. Opening settings, full history, or another window dismisses the panel and clears the temporary pin; the compact indicator stays visible. The menu-bar panel also closes when opening another window.
- Configure each notch side to show the selected quota, its reset, its window name, or nothing. Both sides refer to the same quota. Reset time can be relative, an exact date/time, or hidden.

The menu bar is the default and the fallback when a supported built-in notched display is unavailable. The notch hides for fullscreen and session transitions. Its wings can cover menu-bar items because macOS does not reserve space for them; reduce their width, hide a side, or use menu-bar mode. Haptics depend on a supported trackpad.

In **General**, select a quota refresh interval of 1, 5, 30, or 60 minutes (default: 5). Manual refresh and wake also trigger checks, subject to request guards. Longer intervals can leave readings visibly stale. Low-quota notifications are opt-in. Launch at login is selected by default during onboarding; turn it off there before completing setup, or change it later in General.

## History and meaning

**Quota remaining** shows how much allowance was left on a fixed **0–100%** scale. A falling line means less headroom. Charts open on **3 days** by default; choose 24 hours, 3, 7, 30, or 90 days and select a window for each agent independently of the pinned indicator. The smoothed trend uses fewer display points; hover still shows exact original readings, their window, and time. Dashed lines bridge pauses, corrections, or cycle changes; they do not mean measurements were collected in between. A diamond marks the first reading after a reset, not a measured reset instant. Unknown cycles are dashed, and different accounts or plans are never joined. Equal percentages on different plans do not mean equal tokens or cost.

**Tokens** compares daily account activity on one chart, with a color and total for each supported agent. It shows tokens spent per day, not a running total; these sources do not provide an hour-by-hour timeline. Codex uses the official App Server and Cursor uses its personal dashboard history. Claude's current quota connection does not provide token history, so its total remains unavailable rather than zero.

The period ends on the latest reported day across sources. Codex keeps source calendar dates; Cursor days use UTC. Today may be incomplete. Totals cover only reported days; missing days are unknown, while an explicit zero is zero. Hover for exact counts. A lifetime total appears only when the source provides it. Account activity is not limited to this Mac and requires no conversation reads; token counts are not converted to quota percentages or prices.

Unavailable or unsupported token responses do not break the quota display. Counts stay in memory only; clearing or exporting local quota history does not delete or export provider token activity. Cursor reuses token history for up to 15 minutes, then fetches it on the next quota refresh. Its optional history can be unavailable for a large or incomplete response even when its quota is visible.

Local quota history is retained for 90 days and can be exported as CSV/JSON or cleared from the history window. Older observations are deleted from SQLite when history is read or new readings are recorded, including before export. If LimitRoom was closed, expiration runs the next time it opens and reads history. No quota history is collected while LimitRoom is closed, though the Claude helper can update its latest local reading.

## Data and privacy

- History, latest-reading cache, and Claude helper data live in `~/Library/Application Support/LimitRoom/`. Preferences use macOS UserDefaults.
- **Claude setup backups can contain private settings or secrets.** Treat `ClaudeSetup/` as private recovery data and never attach it to an issue.
- Cursor local-session credentials are memory-only. The alternative web sign-in has its own persistent WebKit session.
- History exports exclude authentication material, email, prompts, conversations, and project paths. Still review any export before sharing it.
- There is no LimitRoom backend or telemetry. Enabled sources contact their own services; update checks contact public GitHub Releases.

Missing and stale values are not zero, full, or unlimited. The source remains authoritative. For a connection problem, report the app/macOS/agent versions and redacted error text, not configuration folders or raw source responses. Use [private reporting](../SECURITY.md) for security issues.
