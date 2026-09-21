# Проверка LimitRoom

## Settings and update-action polish 0.5.1 (7) — 2026-09-22

Prepared for a user-triggered release, not published by this increment. Local artifacts: `build/LimitRoom.app` and the unsigned update archive `build/releases/0.5.1/LimitRoom-0.5.1.zip`. The installed application, provider credentials and Application Support data were not changed.

Confirmed locally:

- Full SwiftPM and universal Xcode Release builds pass. Main, Claude helper and Sparkle contain `x86_64 arm64`; deep/strict app signature verification passes. Packaging validates version 0.5.1, build 7 and the unchanged update public key/feed.
- Xcode has exactly two native targets: LimitRoom and ClaudeBridge. Obsolete extension sources, model/storage projection, publishing calls, configuration and documentation were removed. Historical local data was not deleted; local display snapshot files remain ignored by pattern.
- Strict Swift format, plist/project validation, Bash syntax, actionlint 1.7.12 and Git whitespace checks pass. Targeted tracked-source searches found no recognized credential values or personal checkout paths; this is not an exhaustive secret detector.
- Own-view DEMO renders cover RU/dark and EN/light settings, the general interval selector, and prominent app-update available/downloading/failed states. Available updates use a version-labelled full-width action above the footer, independent of inactive AppKit button tint. Failed-state text stays readable against its orange background. Footer version and quota refresh action remain separate.
- Settings inherit the shared light/dark tint and accent; the selected sidebar section is explicitly accented. Offscreen renders cannot establish native active-window checkbox/slider behavior, keyboard focus or physical hover/click handling.
- Source tracing confirms four allowed polling intervals with a five-minute fallback, persisted outside demo. The existing single display loop checks the selected interval; a due shorter choice uses the same guarded refresh path. Manual/wake refresh and in-flight reads are preserved. Native selection/persistence across relaunch and elapsed-time collection were not exercised against real providers.
- Opening Settings calls the notch controller's existing `close()` before activating the settings window. That path clears the pin and collapses to the compact frame; native pointer/animation interaction remains a manual acceptance item.

No new tests or assertion harnesses were added because no assigned test-case IDs are available. Builds, source tracing and synthetic rendering are not automated regression coverage. Real update replacement/relaunch and first-install Gatekeeper behavior remain separate checks. [Manual release instructions](releasing.md#ready-to-run-051-release) specify Actions → Release, `main`, version `0.5.1`, build `7`; no tag or release needs to be created beforehand.

Fresh read-only review found no Critical or Important issues and two Minor documentation issues. Both were corrected: an old ledger sentence again states that installed-app behavior needs manual acceptance, and an orphan extension reference was removed. Post-review changes are documentation-only; native interaction, timed polling and complete update installation are not newly claimed as verified.

## Settings and signed releases 0.5.0 (6) — 2026-09-21

Local artifacts: `build/LimitRoom.app` and `build/releases/0.5.0/LimitRoom-0.5.0.zip`. The installed app, live agent credentials and provider settings were not changed. The local checks below preceded publication; hosted publication evidence is recorded separately below.

Confirmed:

- Full SwiftPM and universal Xcode Release builds pass after the final fix. Main/helper contain `x86_64 arm64`; deep/strict signature verification passes for the packaged app and again after extracting the ZIP. Bundle version/build are 0.5.0 (6). These are ad-hoc signatures, not Developer ID/notarization.
- Strict Swift format, both Info.plists, Xcode project, Bash syntax, whitespace checks and actionlint 1.7.12 pass. Workflow syntax validation is not a successful GitHub Actions run.
- The official Sparkle 2.10.0 tools generated and verified the archive/feed signatures; SHA256SUMS verifies all staged assets. A dedicated signing key is backed up in Keychain; only its public key is in source. Activation of shared environment signing is covered by the hosted evidence below.
- Own-view Release renders were inspected for RU/EN settings, dark/light appearance, the Cursor connection page, update availability/progress and expanded notch. All synthetic data is marked DEMO. The official Cursor cube geometry and attribution replace the previous pointer mark.
- The opening diagnostic reproduced the clipped/shifted header at the initial collapsed width. After separating the fixed-width dashboard from the actual-width header and updating native geometry atomically, the same own-view sample preserves header positions. This is not proof of smooth physical animation or rapid reversal on every display.
- The reviewed source tree and staged archive contain no recognized credential patterns or personal checkout paths. Targeted ignore rules cover runtime databases, provider settings, logs and private signing material. This is a heuristic audit, not a guarantee against every possible secret. Public history must start from a separate reviewed snapshot with noreply author metadata; original local history must not be pushed.

Fresh read-only review of `ffd2644..d80924e` found no Critical and one Important issue: cancelling a download left `wasCancelled` set, hiding errors in later automatic checks. The final fix resets it with `defer` only in Sparkle's definitive cycle-completion callback, after handling that cycle's error. It deliberately does not reset during the earlier user-driver dismissal callback. Callback ordering was traced in the pinned Sparkle source; post-fix builds, packaging and signature checks pass. A live cancelled-download/next-background-check reproduction was not performed.

Deferred Minor: ordinary information-only update discovery cannot be cancelled through Sparkle's probing driver. It completes before another check can start; cancellation is available for the install check and download. The broader cancellation promise in the design is not fully met.

Acceptance still needed:

- Physical notch movement, rapid direction changes, Spaces, camera alignment, haptics, full-area hit testing and VoiceOver.
- A real signed update from an older installed app through replacement/relaunch, including cancellation, subsequent background failures and first-install Gatekeeper behavior. Version 0.4.1 has no updater and needs one manual installation of 0.5.0.
- Previously documented live Claude/Cursor acceptance remains open. Provider credentials were not accessed for release validation.

No new tests or assertion harnesses were created: assigned test-case IDs are absent. Compilation, source tracing and own-view rendering are not automated regression coverage. No second reviewer was dispatched after the single fix pass.

### Hosted publication evidence

- Explicit approval of the final cancellation fix and publication was received before any remote mutation.
- Public root `5d72f9cdb9edb57f2c127ecbadaf1556176092ed` has no parents and exactly matches the reviewed tree `d91c2812c8107a9f9b45b04916a683ccdffd4434`. Both author and committer use GitHub noreply identity. Anonymous GitHub API reads confirm public access and those metadata.
- [Hosted Build 35650096689](https://github.com/rvrhiv/LimitRoom/actions/runs/35650096689) passed on that root, including SwiftPM/source checks and universal application/signature checks.
- The `release` environment permits only the branch `main`, with no tag or wildcard policy. The dedicated `SPARKLE_PRIVATE_KEY` was transferred directly from Keychain to that environment secret without writing or printing its value. Only secret metadata was read back. No provider credentials were used.
- [Release 35650491179](https://github.com/rvrhiv/LimitRoom/actions/runs/35650491179) passed both build and publish jobs for 0.5.0 (6). Public [tag v0.5.0](https://github.com/rvrhiv/LimitRoom/releases/tag/v0.5.0) points to the verified root; the release is neither draft nor prerelease.
- ZIP, signed appcast, notes and SHA256SUMS were downloaded with curl configuration/authentication disabled. All checksums match the published GitHub asset digests. The stable `releases/latest/download/appcast.xml` endpoint serves the identical signed feed.
- Official Sparkle tools verify the downloaded feed and archive against the dedicated key. After extraction, deep/strict native signature verification passes; main/helper/Sparkle each contain `x86_64 arm64`. The app reports 0.5.0 (6) and embeds the expected public verification key. No installed-app replacement was performed.
- The hosted ZIP SHA256 is `6326fb004dfcbfd76b1f71aedabd5b7664cea10914280f7b6dfa25f106b29469`. Targeted archive filename and executable-string checks found no agent settings/databases, private keys or personal machine paths. This remains a heuristic privacy check.

## Native indicator and Cursor.app connection 0.4.1 (5) — 2026-09-21

Local artifact: `build/LimitRoom.app`. Changes start at `f72f170`. Installed app, real Cursor credentials, Claude settings and GitHub are untouched.

Confirmed:

- SwiftPM build and universal Xcode Release succeeded. Main/helper: `x86_64 arm64`. Deep/strict ad-hoc signature verification passes; bundle reports 0.4.1 (5). Swift-format, both plist files, Xcode project, shell syntax and whitespace checks pass. This is not notarization.
- A temporary DEMO-only probe inspected the real NSStatusBarButton, not a normal offscreen SwiftUI label. Before: `title=DEMO`, `image=nil`, frame 59×22. After: empty native title, complete template image 93.5×18, button 110×22. Own-button PNGs were inspected; the after image contains the agent icon, full circular gauge and percentage. Diagnostic code was then removed. Settings preview uses this same generated image.
- A native invisible NSPanel probe reproduced the layering defect: setting level 26 then `isFloatingPanel=true` changes the actual level to 3. Corrected order leaves level 26; live WindowServer status-item layers on this Mac are 25. The supplied user screenshot shows Zoom's icon overlapping the old 0.4.0 panel. No unsupported/private API or screen-saver-level window is used.
- Ordinary Space and screen-parameter notifications no longer unconditionally hide and reset the notch. Reconciliation retains an unchanged stationary panel; fullscreen/sleep/session/unavailable-display policies remain. This removes the source-level 250 ms hide/show gap; an actual animated Space transition is still a hardware acceptance item.
- All three disclosures (subscription/source, manual Claude setup, alternate Cursor sign-in) use one full-row Button style with hover/cursor/accessibility state. Reset labels have no decorative clock/refresh image. Opening and Settings preview use `.levelChange` haptics with `.now`; user-only opening/cooldown/disable remain.
- Cursor local-session actor and explicit Settings consent compile in both build paths. Only the access-token row is queried; no token is saved, logged, refreshed or sent outside the two fixed cursor.com endpoints. Reads reject redirects, invalid/mismatched/expired sessions and oversized responses. These are source/build checks, not live account validation.

Acceptance still needed:

- Hover/click across whole disclosure bounds, keyboard/VoiceOver, physical haptic strength, Zoom overlap in the new installed build and rapid Control+Arrow/Spaces/fullscreen transitions. The native diagnostics prove label transport and the level reset, not every desktop interaction.
- User-confirmed Cursor.app connection, actual personal usage/plan/reset versus Cursor dashboard, account switch/expiry/offline/disconnect. The development run did not read the real access token or enable this setting. Private Cursor storage/endpoints may change.
- Previous Claude setup, notarization and release-channel gaps remain outside this increment. The Claude setup error visible in the supplied screenshot was not independently diagnosed by this task.

No new tests: no assigned test-case ID exists. Compilation, native diagnostic output, visual inspection and code review do not replace regression coverage. Existing preview renderer adds `--surface connections` for the real SettingsView; it requires DEMO and never invokes authentication.

Fresh read-only review of `f72f170..a05aed6` found no Critical issues, one Important SQLite sidecar write risk and one initially Minor obsolete WebKit message callback. The callback race was regraded Important: an obsolete success/failure could contradict the selected Cursor source's connection result and recovery guidance. Both were addressed in one fix pass:

- Explicit `readonly_shm=1` and Unix VFS prevent the ordinary read-only connection from opening SHM for writes/creation; a SQLite 3.31 floor also guarantees NOFOLLOW support. No writable retry or live-WAL omission. The option's implementation was checked in the official SQLite 3.22 source. This Mac reports SQLite 3.51.0 with Unix VFS; no real Cursor database was opened to verify it.
- Suspending a WebKit source clears its message callback before stopping loading. An in-flight completion can no longer overwrite the selected source's status; existing snapshot-generation guards remain.

Post-fix full SwiftPM, universal Release, deep/strict signature, architectures, version, formatting, plist, shell and whitespace checks were rerun successfully. No new RED/GREEN test was permitted without an ID; no second reviewer was dispatched. No newly deferred Minor findings. Native interaction and real-account acceptance above remain unverified.

## Notch polish and Claude setup 0.4.0 (4) — 2026-09-21

Local artifact: `build/LimitRoom.app`. The installed app, actual Claude settings, accounts and GitHub were not changed. Specs: `2026-09-21-notch-polish-design.md` and `2026-09-21-claude-setup-design.md`.

Confirmed in this increment:

- Full SwiftPM build and universal Xcode Release succeed. Main executable and helper each contain `x86_64 arm64`; deep/strict ad-hoc signature verification passes. Bundle reports 0.4.0. No notarization claim.
- Swift format lint across Package/App/Sources/icon script, both Info.plists/Xcode project lint, packaging shell syntax and git whitespace checks pass.
- Actual Release own-view images inspected: expanded black notch/RU, menu/light/EN, settings/dark/RU, 56/88/120/160 pt wings, independent icon/ring/percentage, ring-only, one hidden wing and exact reset date. No wrap/overlap in these samples; all visible synthetic wings retain DEMO markers. At 56 pt all three components become very small; hiding components or using the default 88 pt improves legibility.
- Native silhouette uses outward circular upper shoulders, no native shadow/outline and an explicit opaque sRGB black fill. Dashboard padding is larger; status panel level is `statusBar + 1`, below pop-up menus. Cursor behavior is implemented but not validated by offscreen rendering.
- Claude setup/helper compile through both packaging paths. Source includes strict JSON/regular-file checks, private backups, compare-before-replace, an installer lock, a recoverable receipt, immutable scope-bound helper copies and previous-command forwarding. Real user configuration was not written to exercise this code.

Still requires acceptance on the user's Mac:

- Physical camera seam and true black match, WindowServer ordering above status icons, native picker/menu ordering and pointing-hand hover across full tab bounds. No screenshot of the reported native seam was supplied, so do not treat source changes or synthetic images as proof that the original seam is fixed.
- One-click Claude setup, a real upstream response, previous statusLine stdout, repeat setup/disconnect, account change, interrupted setup, project overrides and `CLAUDE_CONFIG_DIR` inheritance. Setup success is not authenticated/fresh quota; the UI gives restart/activity guidance. Input forwarded to a prior command is bounded by the bridge's existing 1 MiB input cap.
- Existing haptics/pin/hover/Spaces/fullscreen/session/lid/VoiceOver acceptance remains. Fullscreen hiding and system security overlays intentionally retain priority.

No new tests were created because assigned test-case IDs were not supplied. Builds, visual inspection and source review are not regression coverage.

Fresh read-only review of `89247a8..a4750fc` found no Critical and three Important issues, all addressed in one local fix pass:

- Reconnect now owns the same busy guard as Connect/Disconnect across every await; the internal installer no longer re-enters the public guarded action.
- Serialized settings are size-checked before the receipt/settings commit, falling back to compact JSON when indentation exceeds 4 MiB. The compare check runs after staging, immediately before rename.
- Disconnect invalidates the old producer scope before restoring settings. Scope-independent ownership keeps recovery/removal available after a partial failure and restart. The persisted scope marker takes priority over potentially unflushed UserDefaults, preventing a restart from resurrecting an invalidated producer.

Post-fix full SwiftPM, universal Release, signature, formatting and plist checks were rerun. No new RED/GREEN tests were permitted without IDs, and no second reviewer was dispatched. There are no newly deferred Minor findings. The unchanged native-screen/live-Claude/distribution acceptance boundaries above are deliberate; their cost is possible environment-specific follow-up before any public release.

Images are in `build/v040-*.png`; the existing developer renderer now accepts `--left-components`, `--right-components`, `--menu-components` (comma-separated `icon,ring,percentage`, or `none`) and side widths 56...160. Default width is 88; the normal slider spans 56...120, preserving larger legacy values until changed.

## Integrated notch 0.3.0 (3) — 2026-09-21

Локальный артефакт: `build/LimitRoom.app`. Установленная копия, аккаунты, история и GitHub не изменялись. Только сборки и demo-рендеры собственных views.

Подтверждено:

- SwiftPM собирает все продукты; Xcode Release собрал app/helper targets.
- Главный бинарник и helper содержат `x86_64 arm64`. `codesign --verify --deep --strict build/LimitRoom.app` проходит; Bundle — `0.3.0 (3)`. Это локальная ad-hoc подпись, не notarization и не проверка на Intel.
- `swift format lint --recursive Package.swift App Sources Scripts/generate-icon.swift`, `bash -n Scripts/build-app.sh`, `plutil -lint` обоих plist и Xcode project проходят.
- Из Release получены и осмотрены собственные demo-рендеры: светлый menu/EN, настройки menu/RU, все display controls/RU, компактная/раскрытая чёлка/RU, точная дата при ширине стороны 80 pt, переставленные стороны при ширине 160 pt/EN, скрытый сброс и асимметричная сторона без процента. Камера встроена в единую шапку; отдельной подложки сверху в рендере нет.
- На первом рендере минимальной ширины процент переносился на вторую строку, а Slider дублировал подпись. Исправления проверены повторным Release-рендером: процент в одну строку, подпись ширины одна. Это визуальная проверка существующего renderer, не новый автотест.
- Source review: локальный и глобальный mouse monitors живут только пока панель видима; Escape остаётся локальным. Квоты, SQLite и авторизация не менялись. Никаких новых Accessibility/Screen Recording разрешений.
- Короткая подпись окна теперь использует исходное название, а не только длительность. Ранее отложенное совпадение подписей Cursor-окон с одинаковой длительностью устранено в рамках настройки содержимого сторон.

Что ещё проверить руками на Mac:

- Клик по краям/углам каждой вкладки и её hover/pressed feedback. В коде есть полный rectangular contentShape; рендер не доказывает native hit testing.
- Наведение по всей камере и обоим бокам при активном другом приложении, быстрые пересечения, drag через камеру; отсутствие захвата фокуса и повторных вибраций.
- Булавка, выход мыши, Escape при фокусе панели, открытые native Picker/Menu, смена ширины/содержимого при открытой вкладке настроек.
- Вкл/выкл процента, точный/относительный/скрытый reset, скрытые/переставленные стороны, неизвестные и устаревшие реальные показания.
- Fullscreen, Spaces, Stage Manager, автоскрытие menu bar, сон/крышка/внешний монитор, Reduce Motion, VoiceOver и клавиатурная навигация.

Боковые блоки занимают место menu bar и могут закрывать другие меню/значки. Настройки прямо предупреждают об этом; ширина/скрытие сторон и обычный menu-bar режим доступны. Haptic использует нативный `.alignment`; идентичность NotchNook не обещается.

Новые тесты не создавались: назначенных test-case ID нет. Физические hover/haptics и системные переходы остаются неподтверждёнными.

Независимое read-only ревью `5786aa9..d9614a7` не нашло Critical ошибок. Одно Important замечание подтверждено: компактная чёлка в demo показывала синтетические значения без видимой DEMO-метки. Исправлено общим маркером внутри каждой видимой demo-стороны, вне области камеры. Повторно собраны все SwiftPM-продукты и универсальная Release, проверены подпись/стиль/plist. Из финального бинарника осмотрены PNG компактной чёлки, ширины 80 pt, reset-only и window-only: маркеры видны, процент не переносится. Автотест RED→GREEN не создавался из-за ограничения на test-case ID; это визуальная проверка до/после, не регрессионный тест. Второй reviewer не запускался.

Отложенный Minor: после прошедшего сброса в режиме точной даты видны прежняя дата/время и признак устаревания; фраза ожидания новых данных доступна только в подсказке/VoiceOver. Значения не выдумываются, но явную подпись ожидания можно сделать заметнее.

По темам, которые reviewer не мог оценить без исполнения на устройстве, сохранены решения и их цена:

- Hover/focus над физической камерой, native Picker, ощущение haptic и быстрые движения — ручная приёмка; возможны аппаратно-зависимые доработки.
- Spaces/fullscreen/Stage Manager, дисплеи/крышка и accessibility traversal — ручная приёмка; возможны системные проблемы видимости/навигации.
- Реальные источники, история, notarization и распространение вне этого UI-инкремента; локальная сборка не является подтверждённым публичным релизом.

Повторить новые варианты (только синтетические данные):

```sh
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/v030-settings-ru.png --surface display-settings --dark -AppleLanguages '(ru)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/v030-notch-expanded-ru.png --surface notch-expanded -AppleLanguages '(ru)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/v030-notch-exact-narrow.png --surface notch-compact --reset-style dateTime --side-width 80 -AppleLanguages '(ru)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/v030-notch-asymmetric.png --surface notch-compact --left hidden --right quota --hide-percentage
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/v030-notch-reset-hidden.png --surface notch-compact --reset-style hidden
```

## Presentation refresh 0.2.0 (2) — 2026-09-21

Локальная сборка: `build/LimitRoom.app`. Копия в `/Applications`, аккаунты и реальная история в этом инкременте не изменялись. Выполнены только demo-запуски с синтетическими данными. Публикации и push не было.

Подтверждено:

- Xcode Release собрал app и helper targets. Локальный пакет включает app/helper/иконку.
- `lipo -archs` приложения: `x86_64 arm64`; `codesign --verify --deep --strict` проходит. Это ad-hoc подпись, не Developer ID/notarization и не проверка исполнения на Intel.
- Bundle содержит иконку «Запас», версию `0.2.0`, build `2`, deployment target `14.0`.
- `swift format lint --recursive Package.swift App Sources Scripts/generate-icon.swift` без предупреждений; `bash -n` скрипта упаковки и `plutil -lint` обоих Info.plist/проекта проходят.
- Рендеры собственных SwiftUI views успешно записаны из Release-бинарника: menu bar light/EN и dark/RU, раскрытый notch/RU, компактный notch с процентом и без, индикатор, статистика/EN и настройки/RU. Визуально проверены единые карточки, выбранное окно, русские/английские подписи, версия, отсутствие разрыва между синтетической камерой и контуром, полукольцо и значок агента при выключенных цифрах.
- Статистика использует существующие `model.rates` и независимый выбор окон; легенда связывает цвета с агентами. Отсутствующие/устаревшие данные и сохранение WindowID проверены чтением кода, не имитацией личных данных.
- SwiftPM собирает все продукты. App/helper targets содержат обе архитектуры; в локальном `.app` ровно app, helper, иконка, Info.plist и служебные ресурсы подписи/упаковки.
- Read-only диагностика NSScreen на текущем Mac: встроенный экран `1728×1117`, safe-area top `32`, auxiliary widths `771/772`, вычисленная ширина камеры `185` pt. Внешний экран имеет safe-area top `0` и исключается. Это сверка метаданных, не проверка взаимодействия.

Первый sandboxed Xcode-вызов остановился на запрете записи системного package cache и доступа к build-сервисам. Тот же локальный build с разрешённым доступом завершился успешно; обход в код приложения не добавлялся. Сборки SwiftPM используют task-specific module caches в `/private/tmp`.

Аппаратная проверка остаётся открытой:

- Навести на компактную панель, пройти внутрь/выйти, быстро повторить движение; проверить задержки и отсутствие захвата фокуса у редактора.
- Удержание булавкой, снятие удержания, закрытие, Escape при фокусе самой панели. Глобальный Escape специально не перехватывается.
- Реальная сила/наличие отклика на поддерживаемом трекпаде, отключение отклика настройкой, отсутствие импульсов при запуске/refresh/возврате экрана.
- Reduce Motion, полноэкранные Spaces на встроенном и внешнем мониторе, Stage Manager, автоскрытие меню, сон/пробуждение и закрытие крышки; возвращение только в компактное состояние.
- VoiceOver, клавиатурная навигация, восстановление свёрнутых окон истории/настроек, минимальные доступные размеры дисплея и системное масштабирование.
- Фактическое прохождение указателя через прозрачные плечи и границы окна во время анимации.

PNG не доказывает эти сценарии. Новые автотесты не создавались: назначенные test-case ID отсутствуют. Сборки и source review не являются регрессионным покрытием.

Независимое read-only ревью диапазона `c970847..add6ca7` не нашло подтверждённых Critical/Important ошибок. Один Minor отложен: короткие подписи разных Cursor-окон с одинаковой длительностью совпадают, например «30 дней». Значение и WindowID корректны; полное название доступно в подсказке и карточке. Этот компромисс не выдаётся за исправление.

Повторить рендеры, не запуская реальный сбор данных:

```sh
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-menu-light-en.png -AppleLanguages '(en)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-menu-dark-ru.png --dark -AppleLanguages '(ru)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-notch-expanded.png --surface notch-expanded -AppleLanguages '(ru)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-notch-compact.png --surface notch-compact
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-notch-no-percent.png --surface notch-compact --hide-percentage
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-statistics-en.png --tab statistics -AppleLanguages '(en)'
build/LimitRoom.app/Contents/MacOS/LimitRoom --demo --render-preview build/native-settings-ru.png --tab settings -AppleLanguages '(ru)'
```

## Историческая проверка native foundation — 2026-09-20

Дата: 2026-09-20. Среда: macOS 26.6.2, Xcode 26.2, Swift 6.2.3. Deployment target: macOS 14. Проверка на самой macOS 14 и Intel hardware не выполнялась.

## Подтверждено

| Область | Результат и граница доказательства |
| --- | --- |
| SwiftPM | `swift build`: приложение, helper и все четыре модуля собираются. Новых test targets нет. |
| Форматирование | `swift format lint --recursive Package.swift App Sources` завершился без предупреждений. `bash -n Scripts/build-app.sh` прошёл. |
| Xcode | Debug и Release, `-destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO`: app + helper собраны. |
| Universal | `lipo -archs`: `x86_64 arm64` у app и helper. Это не проверка исполнения на Intel. |
| Локальная упаковка | `bash Scripts/build-app.sh Release`: создаётся `build/LimitRoom.app`. `codesign --verify --deep --strict` подтверждает ad-hoc подпись. Не Developer ID/notarization. |
| Запуск | Обычный процесс LimitRoom запущен. На отдельном замере после старта: 0.0% CPU, RSS 72 496 KiB. Это точечный замер, не performance benchmark. |
| Codex | Найден `/Applications/ChatGPT.app/Contents/Resources/codex`, версия 0.153.4. Официальные RPC вернули ChatGPT account и окно 10080 минут с числовым процентом и reset. Секреты и email в диагностический вывод не включались. |
| App → Codex → Storage | Кэш самого приложения: Codex `ready`, одно окно; в SQLite появилась реальная запись `codex`. Личные проценты не сохранены в репозитории. |
| Claude / Cursor без настройки | Кэш приложения честно содержит `needsSetup`, по нулю окон. Нет demo-значений в реальной истории. |
| Demo | Offscreen-запуски `--demo --render-preview …` завершились с кодом 0. До обычного запуска папка Application Support/LimitRoom отсутствовала. Светлая/тёмная панели осмотрены; три карточки читаются. DEMO указан и в menu bar. |
| Review | Независимое read-only ревью и целевые повторные проверки выполнены. Исправлены replay/неполные данные Claude, потеря кэша при ошибке, гонки переподключения, unlimited и маркировка demo. Последняя целевая проверка не нашла оставшегося воспроизведения двух уточнённых замечаний. |
| Git | Origin указывает на private `rvrhiv/LimitRoom`. Работа локальная, ветка `feat/native-foundation`. Push не выполнялся. |

## Найденные и исправленные проблемы запуска

- SwiftUI `TimelineView` в label `MenuBarExtra` вызвал непрерывную перерисовку на текущей macOS. Стек зависшего собственного demo-процесса подтвердил цикл `MenuBarExtraHost → updateButton`; процесс остановлен. Обновление времени перенесено в модель, с шагом 30 секунд и опросом источников раз в пять минут. Повторный запуск и idle-замер прошли.
- `ImageRenderer` не включал нативный ScrollView в PNG. Для developer preview используется рендер собственного offscreen `NSHostingView`; рабочий стол и другие приложения не захватываются.
- Смешение active-architecture package build с native targets для обеих архитектур исправлено: Debug использует active arch, Universal собирается с generic macOS destination.

## Не подтверждено — нельзя считать готовым релизом

- Live Claude: установка statusLine пользователем, реальные события/сбросы/несколько терминалов. Защита от replay проверена чтением кода, не автоматическими сценариями.
- Live Cursor: успешный WebKit/SSO-вход, соответствие dashboard фактическим цифрам личной подписки. Endpoint и схема приватные, поддержка экспериментальная.
- Сверка отображаемого процента Codex с его UI, реальные исчерпания/сбросы и смена подписки. Транспорт, схема и запись из самого приложения подтверждены отдельно.
- Autostart после перезагрузки, системные permission dialogs уведомлений, VoiceOver traversal, sleep/wake, длительный офлайн и восстановление. Не включались за пользователя.
- UI-действия экспорта/очистки на реальной истории. CSV/JSON allowlist и formula escaping проверены по коду; исторические данные для таких проверок не подменялись.
- Прогноз в интерфейсе, отдельная линия остатка/reset, адаптивный backoff/Retry-After, installer/chaining существующей Claude statusLine — следующие инкременты.
- Sparkle dependency, рабочий appcast, Ed25519-подписи релизов, Developer ID и notarization. Автообновление намеренно неактивно.
- Git push: браузерная сессия не дала рабочую Git HTTPS-авторизацию; SSH strict verification также не настроена. Пароли/токены не запрашивались в чате, host trust не менялся.

## Почему нет новых автотестов

Пользовательское AGENTS.md запрещает создавать новые тесты без назначенных test-case ID. Таких ID нет, они не придумывались. Сборки, ручной запуск, чтение реального источника и source review не заменяют регрессионные тесты. Перед release нужны назначенные IDs для квотных границ, RPC timeout, replay, account switching, уведомлений и хранения.

## Повторить локально

```sh
swift build
bash -n Scripts/build-app.sh
bash Scripts/build-app.sh Release
codesign --verify --deep --strict build/LimitRoom.app
lipo -archs build/LimitRoom.app/Contents/MacOS/LimitRoom
lipo -archs build/LimitRoom.app/Contents/Helpers/limitroom-claude-bridge
```

PNG-предпросмотр генерируется только с `--demo`. Завершите работающий экземпляр через `… → Завершить LimitRoom` перед обычным повторным запуском, чтобы не держать два сборщика.
