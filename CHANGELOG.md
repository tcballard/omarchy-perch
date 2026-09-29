# Changelog

## Unreleased — native modules

- Single compact module strip with up to eight chosen tools, drag/keyboard ordering, settings controls and a persistent switcher above expanded cards. Replaces the original context pill; saved layouts migrate automatically.
- Native QML module descriptors, card/settings host and shared state; all existing pages and Clipboard, Stats and Weather use the same contract. Cards load on demand and retain service-owned state.
- Integrated search/type-filtered clipboard previews from Omarchy's history with race-safe explicit copy; no second capture service or history writes.
- Visibility-driven CPU/memory/root-disk stats and a 30-sample CPU history; selectable refresh interval.
- Opt-in coordinate-based Open-Meteo current weather and six-hour temperatures, bounded fetching and stale-response rejection.
- Portable adapter and production-QML interaction tests, plus a clearly labelled fixture render. Live Omarchy acceptance remains outstanding; see MODULES.md.

## 0.1.0-rc.5 — 2026-09-29

- Hyprland global shortcut `perch:toggle` opens Perch with keyboard focus on the focused display or closes it. Bind it with `bind = SUPER, P, global, perch:toggle`; nothing is written to Hyprland configuration.
- Page changes, Settings and compact context changes fade and slide in over 140 ms, matching the expansion timing. Reduced motion disables them. Countdown ticks do not animate.
- The compact pill shows the current cover instead of the music icon when artwork is available.
- The whole shelf card is now the drag source, with a grip mark; buttons still click normally.
- Timers that ran out while the shell was down alert once on restore if they finished within the last 15 minutes; older ones are shown as finished without ringing.
- Notification review fixes: reply drafts survive snapshot refreshes; a helper command that hits its deadline no longer leaves the job marked running, which had also blocked the inbox resync; the companion retries a slow or failed history read at startup instead of silently dropping persistence for the session; snapshots are never dropped when the bridge is momentarily busy; long unbroken titles, bodies and activity details wrap instead of being clipped; the app filter resets when its app disappears; persisted keys follow the core's rules. The notification companion is at rc.5, so Setup will offer Update now.
- Helper review fixes: open-ended recurring series now expand from the 30-day window instead of stepping day by day since their first occurrence (a realistic export with hundreds of years-old weekly series went from about 5 s, past the helper deadline on add, to about 0.1 s); quoted timezone IDs and Outlook/Exchange names defined by VTIMEZONE resolve with daylight rules instead of dropping the event; `DURATION` is honoured; alarm sub-components no longer leak titles or links into their event; trailing prose punctuation is stripped from detected meeting links; `calendar-add` parses once. Brightness only ever targets a real backlight (brightnessctl otherwise falls back to keyboard LEDs) and Setup reports “no backlight device”. A first companion install whose enable step fails removes its copy again; another plugin's broken manifest no longer aborts Perch setup. Text previews read the head of files of any size. `perch-task run` keeps the controlling terminal so sudo/ssh/gpg prompts work, and transfers publish on filesystems without hard links. Health tolerates a corrupt job file; setup status is recorded only after the worker started; dotfile-managed (symlinked) `shell.json` is read.
- Tests cover shortcut toggling, transition settling, no stale offset when a page is set while collapsed, deferred alerts with the age cutoff, timezone/duration/alarm parsing, window-aligned expansion against exhaustive expansion, parse time, large previews, install rollback and a corrupt job file. The Process test stub now emits an exit after a kill, as the real one does.

## 0.1.0-rc.4 — 2026-09-29

- Dropdown popups (audio devices, timers, apps, notification filter, display and fullscreen settings) now extend the compositor input region and hold the hover grace while open. Previously a pointer-opened Perch collapsed 220 ms after the pointer moved onto a dropdown, which also closed it.
- Helper operations queue behind the running job instead of failing with “An operation is already in progress”; identical pending requests collapse.
- Setup reports enabled companion copies that differ from the installed Perch version and names the failing step when an integration job stops. Companion updates now say to restart the shell.
- Remote artwork is refetched only when the opt-in changes, not on every settings or timer write.
- The compact meeting context ignores all-day entries and meetings that started more than ten minutes ago.
- Without the notification companion the inbox shows the enable hint rather than a failure; an expired action triggers a resync.
- Missing `xdg-open`, `gtk-launch` or LocalSend produce a plain “not installed” message. Unknown notification icon names no longer load a missing-texture image.
- Tests cover popup tracking, helper queueing, meeting summary rules, all-day parsing, companion drift detection and setup failure messages.


## 0.1.0-rc.3 — 2026-09-29

- Contextual compact controls, context cycling and header gestures.
- Persistent file shelf, previews, drag-out and LocalSend handoff.
- Local/synced ICS agenda, meeting countdowns and join links.
- Guided integration setup, health and coordinated removal; optional replacement OSD.
- Persistent notification history/DND/app mutes, unread filtering/icons and supported inline replies.
- Multiple named timers with repeat, snooze and optional completion alerts.
- Audio input/output selection, microphone mute, Bluetooth and brightness controls.
- Display profiles, app pins, opt-in remote artwork and local lyrics.
- Real task adapters, bounded helper regressions and live diagnostics runner.
- Portable tests and actual QML fixture rendering pass; hardware/compositor acceptance remains open.


## 0.1.0-rc.2 — 29 September 2026

- Add an optional notification companion, six-second compact previews, a bounded session inbox, DND, native actions, expiry and stale-action protection. Omarchy clone lifecycle restores the original notification service on companion disable/removal.
- Add Applications, Omarchy menu, Clipboard, Emoji, Appearance and Settings shortcuts.
- Add reversible opt-in Claude Code event hooks and Codex turn-completion notifications, with status-only payloads, silent failure and preserved existing configuration.
- Add inbox/desktop demos, native Qt notification lifecycle and pointer tests, and isolated setup/removal/ownership tests. Keep the stable surface and item-only animation path.

Live DBus ownership handover, real sender actions, agent-client events and desktop focus handoff still require XPS acceptance. No stable tag is made.

## 0.1.0-rc.1 — 29 September 2026

Perch grows from a music preview into an edge companion for playback, focus timers and live progress. It keeps the smoother item animation confirmed on the XPS and adds four focused views.

- Music gains capability-checked seeking, a named player picker, automatic player selection, and opening a supported player from its artwork. Stale seek gestures cannot act on a different player or track.
- Timer offers presets and a custom countdown with pause/resume/cancel. Deadlines and paused time survive shell restarts. Completion stays visible until dismissed.
- System exposes default-output volume/mute and battery/charging state through native Quickshell services. Optional short compact banners reflect volume and power changes.
- Activity accepts bounded, expiring progress cards from scripts or agents. A helper and build-wrapper example show how to report progress without installing hooks.
- Preferences now persist in Perch’s own Omarchy entry: four-edge placement, hide-idle, reduced motion, flush attachment, clock, hover opening and system banners.
- Portable tests cover persistence failure, timers/restoration, activity expiry and limits, seek races, missing devices and real Qt pointer/keyboard interaction. The overview renders actual QML with explicitly fictional data.

This is a release candidate, not a stable tag. The base interaction was confirmed smooth on an XPS; the new features still require live settings/restart, MPRIS/PipeWire/UPower, input mask, focus, install/update and removal checks. No marketplace submission or parity with Island’s desktop replacement features is claimed.
