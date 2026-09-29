# Changelog

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
