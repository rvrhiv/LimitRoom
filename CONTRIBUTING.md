# Contributing to LimitRoom

Small, focused contributions are welcome: clearer setup, reliable readings, native macOS polish, and better documentation. Open an issue before adding an agent or changing account, storage, or release behavior. English and Russian reports are welcome.

For security issues, use [private reporting](SECURITY.md), not a public issue.

## Local development

Use macOS 14+ and full Xcode with Swift 6. The workflow files specify the CI Xcode version. This is a Swift/Xcode project; no Node.js tooling is required.

```sh
git clone https://github.com/rvrhiv/LimitRoom.git
cd LimitRoom
swift build
bash Scripts/build-app.sh Release
open 'build/LimitRoom Dev.app' --args --demo
```

Both Debug and Release local builds are named **LimitRoom Dev**, including when built directly in Xcode. The script signs and verifies a fresh package before replacing `build/LimitRoom Dev.app`, then removes its redundant Debug/Release app products so only one runnable Dev bundle remains in the build folder. Quit the previous Dev instance first. Installed apps, build caches, and official distribution bundles are left untouched. Dev builds never start the release updater; official builds use the explicit `distribution` mode described in [Releasing](docs/releasing.md).

Demo mode is the default development preview: no agent reads, personal persistence, notifications, or update requests. Dev and official builds still share the bundle identifier and data locations. Quit demo mode before launching normally, and avoid running multiple collectors against the same history store.

Read [Architecture](docs/architecture.md) before changing a connector, account handling, history, scheduling, or native presentation. Keep new App files registered in the Xcode project as well as the Swift package. Use the existing localization helpers for both English and Russian.

## Verification

Run the checks relevant to the change and state exactly what they establish:

```sh
swift build
swift format lint --strict --recursive Package.swift App Sources Scripts/generate-icon.swift
plutil -lint Config/App-Info.plist Config/App.entitlements LimitRoom.xcodeproj/project.pbxproj
for script in Scripts/*.sh; do bash -n "$script"; done
bash Scripts/build-app.sh Release
git diff --check
```

For documentation-only changes, check links, assets, language parity, and factual claims; rebuilding unchanged app code is not required. Run a workflow linter when modifying GitHub Actions.

There is currently no automated behavioral test suite. New tests require an assigned test-case ID from the task or issue, included in the test title. Ask for an ID when proposing a test; never invent one. Without an ID, report the coverage gap and use builds, existing tools, and manual checks. Updating or running existing tests does not need a new ID.

For behavior changes, exercise the affected paths:

- **Readings:** unavailable/stale data, resets, account/source switches, cancellation, wake, and configured refresh intervals. Compare live values with the source only through an authorized connection.
- **UI:** both languages and appearances, full-row hit targets, keyboard/VoiceOver, Reduce Motion, and settings persistence.
- **Notch:** hover, pin, reversal during animation, settings opening, menu-bar overlap, Spaces/fullscreen, external display/lid, and supported-trackpad haptics.
- **Updates:** discovery, cancellation/error states, explicit install, and relaunch from a previous installed version.

A build or synthetic screenshot does not prove live authentication, physical haptics, WindowServer behavior, accessibility, or update replacement. Record untested paths in the PR instead of claiming them as passed.

## Screenshots and documentation

Keep the [English](README.md) and [Russian](README.ru.md) READMEs equivalent. Put ongoing guidance in usage, architecture, or releasing docs; use release notes for version-specific changes rather than adding development diaries.

Public images must use synthetic demo data. The existing renderer captures only LimitRoom's own views:

```sh
'build/LimitRoom Dev.app/Contents/MacOS/LimitRoom' --demo --render-preview "$PWD/build/preview.png" --surface notch-expanded --dark -AppleLanguages '(en)'
```

For statistics, use `--surface history` or `--surface menu --tab statistics`, with `--statistics-mode quota` or `tokens` and `--history-days 1`, `3`, `7`, `30`, or `90`. Demo history includes synthetic work sessions, quiet periods, resets, and missing readings across 90 days. Other supported surfaces and options are defined in `App/PreviewRenderer.swift`. README assets live in `docs/assets/`; inspect them before committing. They are interface previews, not evidence of native screen interaction.

Use `--surface agent-details --settings-agent codex` (or `claude` / `cursor`) to render an expanded synthetic card. Only Codex's demo reports remaining extra resets; the other cards demonstrate hidden unknown values.

## Submitting a change

Keep the diff focused, explain the user-visible result, and include verification and known limits. Preserve third-party notices and use a public-safe Git author identity, such as your GitHub noreply address. Contributions are under the project's [MIT license](LICENSE).

Review the exact diff and new files for credentials, real account data, machine paths, and screenshots of other apps. Never attach agent configuration, Cursor databases, WebKit profiles, Claude setup backups, or whole Application Support folders. Build products and private state belong outside version control; `.gitignore` does not sanitize files already committed.

Official publication follows [Releasing](docs/releasing.md). Local development, pushing source, and publishing a release are separate actions.
