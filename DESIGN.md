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

## v0.1.0 scope — 29 September 2026

Tom confirmed the reworked base interaction is much smoother and asked to grow Perch toward Island / Dynamic Island Pro. Their current upstream READMEs were read on 29 September. Island is a bar/menu replacement with a setup companion; Dynamic Island Pro's review notes qualify its decorative waveform and executable-presence agent tile. Perch remains an independent four-edge companion. No upstream implementation was copied.

Accepted implementation scope: durable own-entry preferences, capability-checked seek/raise and named player selection, a durable countdown timer, native default-output audio and UPower battery, clock, short power/volume banners, and an explicitly producer-driven activity API. Keep the stock bar, notifications and keys. No privileged service lookup or parent traversal is used.

Architecture: Service owns Preferences (read shell.json, write own record only through updateEntryInline), LiveState (timer + max eight expiring activities) and SystemState (PipeWire / UPower). Panel owns focus, remapping and placement. NotchView owns page choice and renders the shared state through TimerView, SystemView, ActivityView and PlayersView. DemoMedia provides isolated services. The IPC target remains the plugin ID, adding activity/dismiss/timer/cancelTimer without exposing commands or permissions.

Durable data: preferences and timer transition records in the own shell.json entry. Unrecognized Perch keys are retained on updates. Failed parsing or host writes produce an error. Wall-clock deadlines survive suspension/restart; system clock changes affect them. Activity reports are transient, plain text, bounded to 4096 input characters, max eight cards, 5–86400-second TTL. Status omits user text. No commands run from the service. Optional explicit helper: Python 3 invokes omarchy-shell with argument arrays and a five-second timeout. The build example runs only the exact command the user supplies to that script.

Expanded views: music 344×270 (empty 344×212), secondary views 344×370, settings 344×468. The fixed window grows to the maximum settings height, while only the masked view animates. Compact priority: timer completion/attention activity → enabled system banner → timer/activity → music → clock. No automatic expansion or focus. Position refresh runs only while the Music page is visible and real playback is active. Timer/activity tick at 1 Hz only while needed; idle clock refreshes every 30 seconds and stops if disabled. Native system state has no subprocess polling.

Candidate is 0.1.0-rc.1. Stable tagging awaits live checks for this feature boundary; the XPS confirmation applies to the preceding smoother interaction, not these new integrations. Deferred beyond v0.1.0: remote artwork, audible/desktop timer alarms, notification replacement/inbox, browser-download scraping, automatic agent hooks, desktop menus and AI command execution.

Host lifecycle detail: the inspected PluginRegistry.setEnabled(false) removes third-party plugin entries from shell.json, so disable/remove clears durable Perch settings/timer state. Closing the panel and restarting the shell preserve it. Documentation reflects this boundary.


## rc2 — 29 September 2026

User expanded first-release scope to notifications, desktop menu access and supported automatic agent hooks. This supersedes rc1's deferral of those three features. Candidate is 0.1.0-rc.2.

Notification ownership is an explicit opt-in companion with `omarchy.clonedFrom: omarchy.notifications`; no runtime parent traversal or privileged service lookup. The companion owns native references separately from a bounded 20-row snapshot model. Sender changes refresh snapshots, closure invalidates actions, generation keys prevent old actions hitting a reused ID. Transient notices disappear after expiry. A 100 ms event coalescer sends bounded snapshots via fixed argv to the core inbox IPC; one process per direction at a time, three-second deadline, no idle subprocess polling. No retry loop during host outages. Open/Refresh synchronizes again. History/DND are session-only. No executable hints, remote image loading or inline reply.

The six-second preview fits the existing compact pill; no auto expansion. Bell and monitor icons open inbox/desktop pages, leaving the original four tabs. The desktop page hands off to fixed public Omarchy commands after releasing Perch focus. The compositor surface, 140 ms item animation, four-edge geometry and hover delays are unchanged.

Agent setup is an explicit user-invoked Python tool, separate from plugin enable/update. Claude receives appended command hooks; Codex gets a marked top-level notify block only when no notifier exists. Exact-owned removal, idempotence, dated backups, mode-600 atomic config writes and existing-value preservation are tested. Status adapter accepts at most 64 KiB; emits only generic text and a hashed session identifier; stdout/stderr discarded, no permission decisions, no prompt/transcript forwarding, one-second IPC timeout. Codex support is honestly completion-only per documented notify contract. Managed restrictions are not bypassed.

Remove/disable the notification companion before Perch to restore a visible owner, and remove opted-in agent hooks before uninstall. The companion is copied so deleting a core checkout cannot leave a dangling symlink; setup checks its owned file hashes before update/removal. Automatic dependent-uninstall is not a host capability used here.
