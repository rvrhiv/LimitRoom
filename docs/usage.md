# Using LimitRoom

## Installation

Download the ZIP from the [latest release](https://github.com/rvrhiv/LimitRoom/releases/latest), quit any older instance, and move the extracted app to **Applications**. Put it in this stable location before enabling launch at login. Requirements: macOS 14+, Apple Silicon or Intel.

Early builds are not Developer ID signed or notarized. macOS may block the first launch. Review the source and release before deciding whether to allow it in macOS security settings; do not disable Gatekeeper. Building locally is another option: see [Contributing](../CONTRIBUTING.md#local-development).

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

### Cursor — experimental

Sign in to the installed Cursor app, then choose **Connect Cursor.app…** in LimitRoom and confirm access. LimitRoom reads the current session from Cursor's local store in read-only mode, then requests personal usage from Cursor. It does not derive quota from conversations.

The credential stays in memory and is sent only to fixed HTTPS endpoints on `cursor.com`. LimitRoom neither stores nor renews it. Renew an expired sign-in in Cursor itself; disconnecting LimitRoom leaves Cursor's own sign-in intact.

**Alternative sign-in** uses LimitRoom's separate WebKit profile. Some SSO providers do not support embedded browsers. Choose one source explicitly; LimitRoom does not import browser cookies or silently switch accounts.

Cursor's dashboard endpoints are private and may change. Personal and team pools are not interchangeable, and some fields may be unavailable. Compare readings with your Cursor dashboard before relying on them.

## Choose what stays visible

Select a quota row in an agent card to pin that exact window. Both presentation modes use this selection; browsing another card or the Statistics tab does not change it. Expand **Subscription and source** for the facts the agent actually reports.

In **Settings → Appearance**:

- **Menu bar:** click the indicator to open the panel; choose the agent icon, ring, percentage, or a combination.
- **Near the camera:** hover over the notch to open all cards. Use the pin to keep the panel open after the pointer leaves. Opening settings closes it and clears the temporary pin.
- Configure each notch side to show the selected quota, its reset, its window name, or nothing. Both sides refer to the same quota. Reset time can be relative, an exact date/time, or hidden.

The menu bar is the default and the fallback when a supported built-in notched display is unavailable. The notch hides for fullscreen and session transitions. Its wings can cover menu-bar items because macOS does not reserve space for them; reduce their width, hide a side, or use menu-bar mode. Haptics depend on a supported trackpad.

In **General**, select a quota refresh interval of 1, 5, 30, or 60 minutes (default: 5). Manual refresh and wake also trigger checks, subject to request guards. Longer intervals can leave readings visibly stale. Low-quota notifications are opt-in. Launch at login is selected by default during onboarding; turn it off there before completing setup, or change it later in General.

## History and meaning

Statistics compares observed changes in quota utilization, measured in **percentage points per day**. Select a window for each agent independently of the pinned indicator. Different plans have different capacities: this is not a comparison of tokens, cost, or model efficiency.

History is retained for 90 days and can be exported as CSV/JSON or cleared from the history window. Resets, account/plan changes, corrections, and long gaps break chart continuity. No continuous history is collected while LimitRoom is closed, though the Claude helper can update its latest local reading.

## Data and privacy

- History, latest-reading cache, and Claude helper data live in `~/Library/Application Support/LimitRoom/`. Preferences use macOS UserDefaults.
- **Claude setup backups can contain private settings or secrets.** Treat `ClaudeSetup/` as private recovery data and never attach it to an issue.
- Cursor local-session credentials are memory-only. The alternative web sign-in has its own persistent WebKit session.
- History exports exclude authentication material, email, prompts, conversations, and project paths. Still review any export before sharing it.
- There is no LimitRoom backend or telemetry. Enabled sources contact their own services; update checks contact public GitHub Releases.

Missing and stale values are not zero, full, or unlimited. The source remains authoritative. For a connection problem, report the app/macOS/agent versions and redacted error text, not configuration folders or raw source responses. Use [private reporting](../SECURITY.md) for security issues.
