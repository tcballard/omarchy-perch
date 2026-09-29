# Perch — design and progress

29 September 2026. Scope agreed with Tom: an independent music-first notch, keeping the stock bar in place. Existing alternatives were reviewed; Tom explicitly chose to build his own.

- ID: `io.github.tcballard.perch`.
- Version: `0.1.0-dev`, development preview; source published at https://github.com/tcballard/omarchy-perch.
- Kinds: `panel` → `Panel.qml`, `service` → `Service.qml`, `keepLoaded: true`.
- UI: compact 140/224 logical-pixel surface; expanded 380×250, resized with Omarchy typography/spacing. Default position below stock bar; optional screen edge.
- State: one service selects an MPRIS player and exposes bounded display strings. One panel owns hover, expansion, monitor and session preferences. No durable state is written.
- Host: safe late-injected properties; only own lifecycle via scoped shell API. Native Quickshell MPRIS, no privileged/first-party service traversal.
- Monitor: first screen initially, focused screen on summon, fallback if disconnected. No window per monitor, no duplicate pollers.
- Focus: hover opens without an exclusive grab. Explicit keyboard summon briefly primes exclusive focus, then switches to on-demand and an outside-click focus grab. Collapse immediately releases focus and stops all temporary timers.
- Fullscreen: suppressed, including summons. No overlay above games or video in this version.
- Timing: 1 Hz position notification only while live media is playing and the expanded panel is visible. No idle metadata polling.
- Artwork: local file URLs only, bounded URL length and decoded source dimensions; remote/data/provider URLs rejected. Qt's image loader consumes local files furnished by the user's media player. This is not a hostile-media sandbox.
- Runtime execution: no external commands. Dependencies: existing Quickshell/Qt shell modules and a media player.
- Credentials/network/privilege: none.
- IPC: namespaced `status` returns only state and player count; canonical shell summon/hide manage expanded lifecycle.
- Empty: no player. Pending: service not yet injected. Partial: metadata, artwork, timing or actions missing, each represented explicitly. Playback stopped and paused share an honest label. D-Bus changes remain authoritative; no optimistic playback state.
- Demo: explicit payload only, fictional player, isolated UI controls, resets on close.
- Disable: host unloads service/panel; no child processes, durable data, system edits or replacement bar.

Implemented: native service; surface and controls; hover delay and leave grace; keyboard dismissal; capability checks; session options; fixtures; CI; README; local installation instructions.

Verified: portable manifest and advisory lint; native Qt loading of production view/service with stubs; service data transitions; production lifecycle JS; rendered production view. Live Quattro acceptance outstanding; see TESTING.md.

Deferred: persistent shell.json preferences, bounded remote artwork downloads, seek interaction, charging notices, notifications, files, calendars, agents and Familiar Desktop integration. Do not describe these as implemented.

## Perch / four-edge update

Tom chose the Perch name and requested all four screen edges. The plugin ID is now `io.github.tcballard.perch`; the README includes migration from the earlier local preview. Edge selection remaps the layer surface after collapsing, with one selected anchor at a time. Top/bottom expand vertically; left/right use 36×108 compact tabs and expand horizontally into upright controls. Bar clearance is applied only when the visible bar shares the selected edge. Edge choice remains session-only.

Added tests exercise every edge, all edge/bar combinations, runtime view dimensions and rotation, plus production setEdge lifecycle and focus release. Live compositor verification remains outstanding on all four edges.

## Interaction rework after XPS feedback

The first version appeared as a generic light popup and felt sluggish. Replace that view with theme-derived dark notch chrome, drawn transport icons, 96×30 idle / 208×30 playing horizontal pills, 28×80 vertical tabs, 344×148 empty / 344×208 player / 344×336 settings views. Earlier dimensions above describe the original implementation. No visualizer animation runs at idle.

Keep one 344×336 compositor surface (width bounded to screen), and animate only the masked view's dimensions over 140 ms. Anchor the view inside that surface to the selected edge; top/bottom stay horizontally centered and side tabs stay vertically centered. HoverHandler follows the masked view, not the transparent envelope. Content layout has fixed expanded dimensions while clipping and fading. Hover is 90 ms; leave grace 220 ms. Pointer opens retain the hovered monitor. Edge selection preserves the open view and demo state while remapping, releases focus priming and resumes it after the remap. The compositor still receives input-region updates during animation; no claim of zero compositor work.

The darker of theme foreground/background drives chrome and the lighter drives ink, including light themes. Settings replace the player view; Escape backs out of Settings first. No player means no dead transport row or empty progress line. Preferences remain session-only.
