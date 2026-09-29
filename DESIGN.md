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

## Full gap closure — 29 September 2026

User authorizes addressing every comparison gap. Preserve the stable hosted surface. Implement guided integration setup/health/removal; contextual compact actions and gestures; a durable reference-only file shelf with previews/open/reveal/share and native drag-out; local ICS calendar/meeting support; multiple named timers and completion options; native audio input/output and Bluetooth plus optional brightnessctl; monitor/size/offset/fullscreen preferences; pinned desktop actions; bounded opt-in artwork and local lyrics; practical build/download/copy activity adapters; and durable notification history/DND/app controls/replies where advertised by the sender.

Use Python 3.11 stdlib helpers only for operations that QML cannot perform safely. Keep normal settings inline in the own host entry; shelf/calendar/history runtime data in private XDG state, artwork in bounded cache. User actions own setup, file open/share, calendar join and network opt-ins. No privileged setup or credential scraping. Existing Linux applications handle sharing and opening; do not imitate proprietary AirDrop or invent unsupported agent events. Account-based calendars, hardware-dependent output switching, sender replies and compositor behavior must retain honest capability and test boundaries.

Completion evidence requires production-path tests for helper bounds/persistence, state-machine interactions, actual QML rendering, and a reproducible live acceptance/performance runner. No physical XPS/display is available here; actual hardware latency, Bluetooth, suspend, DBus ownership and agent-client end-to-end observations remain a live gate rather than fabricated evidence.


### rc3 implementation record

The scope above is implemented as 0.1.0-rc.3, with exact platform boundaries in GAPS.md. New views keep the fixed compositor envelope; expanded music is 310 high, secondary pages 430, settings 468, with scrolling where needed. WorkspaceState serializes bounded helper jobs; configured ICS refreshes every five minutes, and setup status polls only while a detached setup worker is active. Detached integration jobs survive the shell rescan they trigger, have finite command deadlines and durable coarse status. File references/calendar/history are separate private XDG state; artwork cache is bounded. Notification actions/replies are never restored from disk. The optional OSD companion uses the same owned clone lifecycle as notifications. Timer transitions persist at most eight timers; simultaneous completion alerts are serialized.

The new Python task adapter executes only explicit argv, caps transfers, publishes without overwriting destinations, removes temporary transfers on failure and kills its process group on cancellation. No browser inspection or inferred progress. Live diagnostics measure whole-shell CPU/RSS and IPC, explicitly not frame latency. Production-path portable tests pass and actual QML renders were inspected; native Wayland/DBus/hardware gates remain open. Earlier chronological deferrals and session-only descriptions are superseded by this record.

### rc4 review record — 29 September 2026

Continuation without XPS access. Fixes preserve the stable surface and the 140/90/220 ms timings: dropdown popups are the one case where interactive content leaves the masked item, so the panel adds the window overlay to its input region only while a popup is open and treats the open popup as hovered. No other mask or animation change. Helper serialization uses a bounded eight-entry queue that collapses identical requests; it does not add polling. Companion drift detection compares installed companion files with the checkout's; it never rewrites anything by itself. Setup failure messages carry the failing step and the setup script's last status line, which are paths and reasons, never configuration contents. Version is 0.1.0-rc.4; the live gates in TESTING.md are unchanged in kind.

### rc5 polish record — 29 September 2026

Tom asked for robust and awesome. Robustness work continues as review-driven fixes; the polish adds only what touches confirmed-smooth paths: a Hyprland global shortcut (appid `perch`, name `toggle`) because a summon command in a bind is not a product; enter-only transitions for pages, Settings and compact contexts using the existing 140 ms curve, keyed on context kind so countdown ticks stay static; the current cover in the compact pill; the whole shelf card as the drag source; and deferred alerts for timers that finished while the shell was down, cut off at 15 minutes so a stale timer never rings hours later. Version 0.1.0-rc.5. A second adversarial pass over the notification path found no state-machine fault but did find the deadline path completing a job before its process was reaped, which made the new inbox resync a no-op after a hung command; completion now follows the real exit. The notification companion moves to rc.5 for the history-read retry and the bridge retry.


## Native modules — 29 September 2026

Accepted direction: an optional user-configurable compact strip, a shared native
QML card/settings/actions contract, and Clipboard/Stats/Weather through that
contract. Keep the context pill and current Omarchy plugin identity/kinds. No
Bun/TSX runtime or nested plugin marketplace. Shared data stays in Service;
placement/selection/hover stays in NotchView. Bounded IO reuses the existing
isolated helper path. MODULES.md records dependencies, persisted state, network
opt-in, module extension steps and remaining live acceptance.

## Single layout migration — 29 September 2026

Tom confirmed that he is the sole user of the old view and authorized migration.
The module strip now replaces the pill, without a legacy-layout switch. Every
existing page is registered as a trusted PerchModule card; only the selected
card loads. Services retain timers, media, files and other state across navigation.
All tools remains a route to unselected modules. The fixed expanded envelope is
468 logical pixels high; natural-height cards scroll inside the shared host.
Old pill/hide-idle/idle-clock settings do not restore the removed view.

## Plugin pins — 29 September 2026

Tom requested Perch as a home for installed plugins. First slice: user-selected
launcher tiles mixed with the eight built-in module slots, using existing
ordering and persistence. IDs use the `plugin:` prefix and cannot name a path.
Discovery uses public `omarchy-shell shell listPlugins` IPC, at startup and on
explicit refresh. Only third-party panel/overlay/menu/bar-widget entries appear;
services, replacement bars and Perch itself are excluded. Some bar widgets have
no summonable panel; the host's rejection is shown. No auto-enable or installation.

An explicit click revalidates the target then invokes public `shell summon` with
an argv array, fixed empty payload, bounded output and deadlines. Hover never
launches plugins. The self-scoped injected shell API remains untouched. A launch
releases exclusive keyboard mode, holds leave-grace while pending, and collapses
Perch on success. Errors remain visible in settings. Missing pins remain removable.
No arbitrary QML loader, polling loop, new dependency or credential access.

Portable evidence covers catalog filtering, stale enable/removal, malformed IDs,
real Qt tile clicks/hover and persisted strip rules. Live cross-panel focus and
plugin-specific summon behavior require XPS verification. Embedded cards and
a first partner integration are deferred until this launcher path is proven.
