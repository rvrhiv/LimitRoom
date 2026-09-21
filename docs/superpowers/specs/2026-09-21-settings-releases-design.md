# Clear settings, stable notch motion and signed releases

## Intent

Replace the placeholder Cursor pointer with the official cube, make settings understandable, remove notch-header jumps, and establish a public GitHub release channel with a compact update indicator and user-initiated installation. Preserve Codex/Claude/Cursor, RU/EN, one account per agent, private local history, macOS 14+, existing preferences and approved cards.

The user explicitly requested privacy review, code push and then public visibility. Earlier permission to save documents and implement without intermediate approvals remains in effect. Publication is conditional on a clean reviewed snapshot and authenticated GitHub access. Do not publish the original local commit history containing personal identity metadata. No installed-app replacement, live agent credential reads or new tests without assigned IDs.

## Settings and branding

Use a native sidebar window, minimum 800 by 640, with Appearance, Agents, Notifications, General, Updates. Appearance has a live preview and segmented presentation switch; show relevant menu/notch controls, editing one notch side at a time. Preserve all current preferences. Agents uses a three-agent selector and a single selected connection card, clear status and primary connect action. Advanced paths/manual configuration remain available behind explicitly labelled secondary disclosure. Preserve consent, disconnect and Claude account-history separation.

The compact dashboard Settings tab is a summary with preview, presentation switch and one clear button to the full window, not another copy of all controls. Agent connection actions open the Agents page. Icons use the official Cursor 2D cube path from https://cursor.com/brand; no generated approximation, original proportions and third-party attribution.

## Notch motion

Gather own-view frame diagnostics before a fix. The header's physical-camera coordinates and native panel frame must be updated atomically, without a second implicit SwiftUI animation. Header slot content keeps a stable width/identity while the panel reveals; no text reflow or scale change per frame. Body appearance may animate independently. Preserve top anchoring, hidden-wing behavior, rapid reversal, Reduce Motion, pin, haptics and fullscreen policies. No continuous idle clock and no desktop capture.

## Update boundary

Use Sparkle 2.10.0 rather than an application-written installer or shell replacement. UpdateController owns one SPUUpdater and a custom SPUUserDriver on MainActor; it never consumes quota credentials. A signed HTTPS appcast lives at the GitHub latest release asset URL. Embed only an Ed25519 public verification key. Require signed feed and pre-extraction archive verification. Missing configuration disables updates honestly; demo never starts the updater.

Scheduled checks show a small badge, not a modal. The footer action shows available version, download progress and errors. An explicit Update click authorizes that displayed version's download, verification, installation and relaunch; no silent install on discovery. If a different version is found, require a fresh click. Information-only/paid updates are not installed automatically. Cancellation is available during checking/downloading. OS authorization, if required, remains native. Unsupported OS/network/signature failures leave the current app intact.

Keep automatic checks separately configurable; no telemetry/system-profile submission. Settings show current version, last check, status, check/install and release-notes link. An initial manual upgrade from 0.4.1 is required because it has no updater.

## Release and publication

Audit current tracked files, all reachable history, commit metadata and public assets without printing secrets. Add targeted ignores for agent credentials, runtime databases/logs/backups and release signing material. Replace personal checkout paths with portable instructions. Keep bundle/project owner identifiers as intentional public identity. Publish one sanitized initial commit using verified GitHub noreply identity; preserve original local branch. Never push --all/--mirror or historical tags.

GitHub CLI authentication uses the user's browser confirmation, no pasted tokens. Source visibility becomes public only after exact remote content is verified. License choice remains the user's; absent a reply, do not invent a license grant.

Release scripts build a universal app, package only the app, sign archives/feed with Sparkle tools and fail closed when the verification key or signing key is unavailable. Private signing material stays outside tracked sources. GitHub automation builds/checks releases with minimal permissions; publishing a usable signed channel requires the signing-key setup. Apple Developer membership was previously unavailable: Ed25519 integrity does not imply Apple notarization, and first-install Gatekeeper limitations must remain visible. Do not disable OS security or promise notarization.

The user approved project-wide signing via GitHub Actions, not Mac-only publishing. A dedicated long-lived Sparkle key is backed up in local Keychain and its private value uploaded directly to a GitHub Actions environment secret without displaying it. Only trusted main-branch release workflows can access the protected `release` environment. Authorized collaborators can run the release workflow without the owner's Mac. Untrusted pull requests get builds only, never signing secrets. Public users need neither GitHub login nor private keys to receive updates. The release workflow checks out an exact main commit, builds before exposing the key, signs in a separate step, and publishes only validated artifacts.

## Verification

No assigned test-case IDs: no new tests or assertion harnesses. Use existing SwiftPM/Xcode builds, formatting, plist/shell checks, own-view renderer and temporary frame diagnostics. Record native motion, update replacement and live-account gaps separately from compilation. Review the whole increment once before publication; any review-fix remote approval gate remains in force. Scan the exact final publication tree and public author metadata again.

References: https://cursor.com/brand ; https://sparkle-project.org/documentation/ ; https://sparkle-project.org/documentation/programmatic-setup/ . Checked 2026-09-21.
