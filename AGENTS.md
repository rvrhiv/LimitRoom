# Working on LimitRoom

LimitRoom is a native macOS quota monitor, not an agent runner. Current product scope: Codex, Claude Code, and Cursor; one active account each; menu-bar or notch presentation; local history; English/Russian UI. This is a standalone Git repository.

## Read by task

- **Build, checks, screenshots, or contribution workflow:** [CONTRIBUTING.md](CONTRIBUTING.md).
- **Connectors, account identity, storage, scheduling, or native presentation:** [docs/architecture.md](docs/architecture.md) before changing behavior.
- **Connection flow or user-facing guidance:** [docs/usage.md](docs/usage.md).
- **Updater, signing, packaging, CI, or publication:** [docs/releasing.md](docs/releasing.md); inspect the relevant script/workflow before executing it.
- **Security report or suspected secret exposure:** [SECURITY.md](SECURITY.md).

## Work loop

1. Check the current branch and working tree. Identify the requested scope and preserve unrelated edits. Diagnose bugs with concrete evidence before choosing a fix.
2. Keep provider-specific formats inside connectors and platform APIs in the App layer. Follow the existing module boundaries; keep SwiftPM and Xcode source membership consistent.
3. Run the relevant checks from CONTRIBUTING. Inspect UI changes through demo previews, then separately identify native or live-source checks that were not exercised.
4. Review the final diff and report the result, checks, and remaining limits. A successful compile does not establish live integration or release readiness.

## Non-negotiable boundaries

- Preserve truthful readings: missing/stale data is not zero, full, or unlimited. Selection identifies an agent and window; source/account changes invalidate obsolete asynchronous work.
- Use `--demo` for previews. Do not inspect real credentials, connect live accounts, modify agent settings, replace an installed app, or send notifications as an incidental development step.
- Keep credentials and personal content out of source, logs, screenshots, exports, and history. Claude setup backups are private recovery files, not bug-report attachments.
- New tests need an actual assigned test-case ID in their title. If none is available, skip creation and report that limit; never invent an ID. Existing tests may be run or minimally updated.
- Publishing requires explicit authorization. After fixing review findings, present the fix and wait for approval before pushing, changing a PR remotely, replying, or resolving its discussion.
- Publish only the reviewed public branch lineage. Never push all local branches, mirror this repository, or implicitly upload historical tags; local development history may contain private metadata.
- Keep signing secrets out of the checkout and leave Gatekeeper, quarantine, and release protections intact. Do not rotate keys or dispatch a release as a side effect of another task.

## Presentation and docs

Reuse the shared agent cards, indicator renderers, and localization helpers. Preserve full hit areas, hover feedback, keyboard/accessibility labels, Reduce Motion, and optional haptics. Avoid adding timers or a `TimelineView` to the menu-bar label; see architecture for native lifecycle constraints.

Keep README.md in English and README.ru.md equivalent in Russian. Update existing guides instead of accumulating plans, interviews, or verification diaries. Public screenshots use the app's own synthetic renderer. Third-party marks remain covered by their own terms, not the project's MIT license.
