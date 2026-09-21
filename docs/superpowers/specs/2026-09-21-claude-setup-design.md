# Explicit one-click Claude Code setup

## Contract

The Claude Agent Card and connections settings offer Connect. A click installs the bundled bridge at a stable path under LimitRoom's Application Support directory and configures the user-level Claude `settings.json` statusLine. It does not sign in, consume quota, read credentials or edit projects/managed settings. Respect `CLAUDE_CONFIG_DIR` when present in the app environment; otherwise use `~/.claude`. Explain that project overrides can take precedence.

Preserve an existing command-based statusLine, including its extra settings and displayed output. Feed the same in-memory stdin to the previous command, without storing input or reading transcripts. If its type/shape is unsupported, JSON is malformed/oversized, or the target is a symlink/non-regular file, fail with an actionable message instead of replacing it. An explicit backup and local integration receipt make setup reversible. Repeated Connect must not recursively wrap the bridge.

Back up the original settings bytes in a private file before replacing settings atomically. Preserve unrelated JSON values. Check the current bytes again before replacement and reject a concurrent edit. Keep immutable helper/backup paths valid across app relocation and account reconnection. Receipt identity must match the actual installed command before treating it as managed. Disconnect restores only the previous statusLine field, never the entire old settings file; refuse to overwrite a command changed by somebody else. Keep backup/helper files recoverable.

Persist the account scope in each installed invocation, not a dynamically read 'current scope': an old terminal must remain unable to publish into a new account's history. Reconnect rotates scope through the existing store and reinstalls the managed invocation explicitly. Configure/waiting and fresh quota are separate states. Missing upstream `rate_limits` must not become zero or fabricated subscription information.

Recovery details: all connection actions hold one busy guard across awaits. Disconnect persists a new scope before restoring settings; scope-independent managed-command identity permits retry/removal after interruption. On startup the atomically persisted scope marker takes precedence over UserDefaults. Both formatted and compact settings output must remain within the same 4 MiB read limit before any configuration commit.

## Boundaries

`ClaudeSetup` in AllowanceConnectors owns explicit setup/removal and its receipt. Collectors remain read-only. AppModel owns UI messages and busy state; the bridge owns filtering and optional forwarding. No shell profile changes, downloads, background daemon, authentication automation or new network requests.

Claude Code supplies quota fields through statusLine only when supported and after agent activity. The UI says to restart an existing Claude session if required and wait for an answer. Existing documentation presently describes Pro/Max availability; unsupported accounts or project overrides may produce no quota. Do not declare a live connection merely because configuration succeeded.

## Verification

No new tests without assigned test-case IDs. Compile both helper and app, review malformed settings/conflicts/chaining/account-scope paths, and explicitly leave live setup/previous-command execution for user acceptance. Do not modify the user's Claude settings while developing or use their credentials to verify.

Sources: [Claude statusLine](https://code.claude.com/docs/en/statusline), [settings and precedence](https://code.claude.com/docs/en/settings).
