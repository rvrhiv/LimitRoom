# Notch polish and circular indicators

The user's accepted design remains the baseline. This increment has two bounded parts: native presentation polish (this document) and a Claude setup boundary (`2026-09-21-claude-setup-design.md`). The latter is architectural because it introduces explicitly user-triggered configuration writes, separate from read-only collection. The user already authorized saving documents and implementing without additional approval stops. Continue locally in the existing feature checkout.

## Presentation contract

- Replace the Codex curly-braces symbol with the monochrome ChatGPT/OpenAI Blossom in agent-identification contexts. Keep LimitRoom's own icon and name unchanged. Attribute the third-party mark.
- Compact quota order is agent icon, full circular remaining-allowance ring, percentage. Each component can be hidden independently per wing; menu-bar components have their own preferences. Disabling every wing component hides that wing; the menu-bar indicator always retains at least one component so the app remains reachable.
- Both wings still reference the same pinned AgentID + WindowID. Keep reset, window-name and hidden slot choices, freshness/missing indicators, honest unknown values, and visible DEMO identification.
- Side width defaults to 88 pt. The slider uses 56...120 pt, step 8; 88 is exactly its midpoint. Preserve previously saved widths up to 160 pt through a legacy-aware expanded range, while offering an explicit 88 pt reset. Never reset a user's saved width silently.
- Do not add a new collapsed gap: the user withdrew that request. The collapsed panel remains camera-height tall.
- Expanded body gets balanced 22 pt horizontal and 12 pt top/bottom breathing room, without shrinking card tap areas. Top corners are outward quarter-circle shoulders; bottom corners remain rounded. Use an opaque black fill, no outline, no native window shadow or material over the camera. No fade of the background during opening.
- The borderless panel sits above menu-bar status items, but below native pop-up menus, security UI and system overlays. Keep existing fullscreen hiding, sleep/session handling, mouse-only hover, haptics, pin, Escape and Reduce Motion behavior. This is not a promise to cover every system surface.
- Dashboard tabs retain full-area hover/press/click and gain a pointing-hand cursor for the entire target; removing a tab view restores cursor ownership.

## Architecture and verification

`AgentIcon` owns the UI-only brand mark. `IndicatorComponents` is the small persisted value used by menu/left/right renderers. `CompactIndicatorView` and settings previews use the same renderer; no extra model or collector. Keep the existing 30-second display clock.

The existing source already fills the silhouette black and has no explicit stroke; source inspection alone therefore does not establish the reported physical seam's cause. Own-view renders can verify geometry, padding and black pixels, not the physical cutout, WindowServer ordering or hover/cursor hardware behavior. Report that remaining native acceptance explicitly.

No assigned test-case IDs are available. Do not create new tests. Run existing builds, own-view renders, formatter, plist and signature checks, then a fresh code review. Leave the installed app and real Claude settings untouched during development. Build local version 0.4.0 (4), universal and ad-hoc signed; do not push or publish.

## Sources

- [OpenAI brand guidelines](https://openai.com/brand/), Blossom vector shown on the official page; use only as an agent identifier, not app branding.
- [Apple window levels](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct) and [pointing-hand cursor](https://developer.apple.com/documentation/appkit/nscursor/pointinghand).
