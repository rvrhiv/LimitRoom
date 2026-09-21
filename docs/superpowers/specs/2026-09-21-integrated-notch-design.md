# Integrated notch and display controls

## Decision and scope

Show **one selected quota**, not two independent quotas. The user's answer on 2026-09-21 closes this choice. Their earlier instruction to save documents and implement without additional approval gates still applies. Work locally in the existing feature checkout; do not install, push or publish.

Keep the approved cards, icon A, dark notch appearance, temporary pin and version footer. Do not change collectors, account access, SQLite or chart selection.

## Interaction contract

- Every dashboard tab has a full rectangular click target, hover feedback and pressed feedback, with an unchanged selected state and keyboard/accessibility behavior.
- Collapsed notch content occupies the menu-bar strip on either side of the physical camera. Nothing extends below the camera when collapsed.
- Hover over either wing **or the camera region** opens the integrated panel after 220 ms. Pointer exit closes after 360 ms unless pinned or an app menu is tracking.
- The camera region is part of the black silhouette and contains no controls. All cards and tabs appear below it when expanded.
- Restoring a display, switching Spaces or starting under a stationary pointer must not open the panel or trigger haptics. Dragging across the notch must not open it.
- Keep the existing native alignment haptic, once per actual user expansion and rate-limited to 800 ms. A settings button explicitly previews it. Hardware/macOS preferences determine whether it is felt; no claim of an identical NotchNook waveform.
- Reduce Motion skips frame animation. Otherwise use a finite, cancellable, top-anchored expansion. Keep the physical camera aligned throughout asymmetric resizing.

## Display preferences

Both wings use the same `AppModel.selection` (AgentID + WindowID). Defaults: left quota (glyph, half-ring, optional percentage), right reset.

Each side can display quota, reset, quota-window name, or nothing. Reset format is hidden, relative time remaining, or exact local date and time. Reset text uses `resetsAt`, never window duration. An elapsed reset says it is waiting for fresh data; an unknown reset displays a dash. Stale readings remain marked. Window names distinguish different categories even when durations match.

Shared percentage preference remains available. Side width is configurable from 80 to 160 points, default 112; hidden content takes no width. Exact-date mode uses two compact lines. Previews and help expose untruncated information.

Menu-bar and notch previews update immediately from the same model and render primitives used by the actual UI. Previewing must not create another collector, native presentation, notification or haptic. Real missing data stays missing; synthetic renderer data is marked DEMO.

The OS does not reserve free menu-bar space for wings. Explain this limitation in settings; allow narrower/hidden wings or switching to menu-bar mode. Do not request Accessibility/Screen Recording or use private APIs to move other applications' menus.

## Architecture

`PresentationPreferences` owns persisted display choices and emits a separate layout-change callback. `NotchHeaderView` and its slot renderer are shared by the actual header and settings preview. `CompactIndicatorView` remains the menu-bar quota renderer.

`NotchGeometry` derives camera bounds from the built-in display's safe area and auxiliary top regions. One borderless nonactivating panel at status-bar level contains both the camera-height header and the expanded dashboard. The collapsed frame is the exact header bounds; the expanded frame is at least 430 points wide. Both frames end at the physical screen top. Remove the separate camera decoration window.

The panel state carries camera height/width and its leading offset in the current animated window. Interpolate x, width and height, but compute the camera offset from its fixed screen coordinate on every frame. Layout changes resize in place without clearing pin or the selected tab.

Local/global mouse monitors supplement the view tracking area so camera hover also works over other active apps. Read pointer position only; do not retain events, monitor global keyboard events, block events or add a polling timer. Install while visible, remove on hide/stop. The existing local Escape handler remains.

Keep fallback on non-notched/external displays and existing sleep/fullscreen/Space handling. Hold state resets on lifecycle hiding. Mode preference survives temporary fallback.

## Verification and limits

No assigned test-case IDs were supplied, so create no new tests. Run existing SwiftPM and universal Release builds, formatting/plist/signature checks and synthetic own-view renders. A fresh code review checks input/lifecycle failure modes; these checks do not prove hardware interactions.

Manual acceptance on the user's Mac: click tab edges/corners; inspect hover/press; traverse camera and wings slowly and rapidly; pin/unpin; open native pickers; swap/hide wings; set exact/relative/hidden resets; resize wings while expanded; use another active app, Spaces/fullscreen, external display/lid, Reduce Motion and a supported trackpad. Verify no focus stealing, no collapsed body hit area and no repeated haptic pulses.

Local artifact: `build/LimitRoom.app`, version 0.3.0 (3), universal and ad-hoc signed. No `/Applications` replacement and no notarization claim.

## References

- [Apple event monitors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html): local/global scope and monitor cleanup.
- [Apple haptic manager](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager): native input-device feedback.
- [NotchNook](https://lo.cafe/notchnook): user-provided behavior reference, not a dependency. Its live page could not be visually inspected because of a TLS error; no security bypass was attempted.
