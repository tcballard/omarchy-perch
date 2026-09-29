# Perch

[![Built for Omarchy: Plugin](https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg)](https://github.com/tcballard/omarchy-badges)

Music, timers, notifications and live progress at any edge of your Omarchy desktop. A small pill opens into the controls you need, then gets out of the way.

**v0.1.0-rc.2 — release candidate.** Adds an optional notification inbox, desktop shortcuts and opt-in Claude Code/Codex hooks. The smoother base interaction is confirmed on the XPS; rc2 passes portable/Qt fixture checks and still needs live acceptance in [TESTING.md](TESTING.md). No stable tag or marketplace claim yet.

![Perch’s actual QML views with fictional media, timer and activity fixtures](preview.png)

## What you get

- **Four edges:** top, bottom, left or right; slim upright side tabs; optional flush attachment. Choose an edge without closing Settings.
- **Music:** title, artist, local artwork, previous/play/pause/next, seek when supported, and a named player picker with automatic selection. Click artwork to raise a player that supports it. Middle-click the compact pill to play/pause.
- **Timers:** 5/15/25-minute presets, custom 1–1440-minute countdowns, pause/resume/cancel, compact progress and a persistent “finished” state. Real timers survive closing Perch and restarting the shell.
- **System:** default audio output volume/mute, battery percentage and charging state. No device means an explicit unavailable state.
- **Live activities:** builds, backups, downloads or agents can report progress through a small IPC API. Cards support running, waiting, complete and failed states, with dismissal and expiry.
- **Notifications (opt-in):** compact previews, a 20-item session inbox, DND, dismissal and supported native actions. A separate companion takes over from Omarchy notifications only when you enable it.
- **Desktop shortcuts:** Applications, Omarchy menu, Clipboard, Emoji, Appearance and Settings through the monitor icon. Existing Omarchy menus open after Perch collapses.
- **Agent hooks (opt-in):** Claude Code working/attention/completion events and Codex turn completion. Reversible setup, status-only payloads and no permission decisions.
- **Persistent preferences:** edge, hide-idle, reduced motion, flush attachment, idle clock, hover opening, and volume/power banners. Saved to Perch’s own entry in Omarchy’s `shell.json` through the host API.

The compact view prioritizes a finished timer or activity needing attention, then notification previews, short volume/power feedback, a running timer/activity, music, and the clock. It never expands automatically or takes focus to show an update. Fullscreen workspaces suppress Perch until you leave fullscreen.

## Install or update

Requires Omarchy Quattro’s plugin-capable shell with the scoped `updateEntryInline` API, QtQuick Controls/Layouts, Quickshell MPRIS, PipeWire, UPower, IO, Wayland and Hyprland modules, plus Omarchy’s `qs.Commons` and `qs.Ui` modules. These are provided by the target shell; a media player must expose MPRIS for music controls.

```bash
omarchy plugin add https://github.com/tcballard/omarchy-perch.git --enable
```

Existing installation:

```bash
omarchy plugin update io.github.tcballard.perch --yes
omarchy restart shell
```

Open on the focused monitor:

```bash
omarchy-shell shell summon io.github.tcballard.perch
```

Open a particular view:

```bash
omarchy-shell shell summon io.github.tcballard.perch '{"page":"timer"}'
```

`page` accepts `music`, `timer`, `system`, `activity`, `players`, `inbox` or `desktop`. Hover opening stays on the hovered display. Keyboard summons select the focused display. Startup uses the first display; unplugging it falls back to an available display.

## Controls

Hover for 90 ms or click the pill to open. Expansion animates the visible item for 140 ms inside a stable compositor surface. A 220 ms leave grace lets you move between controls. Disable hover opening to require a click; reduced motion disables expansion/fade animation.

Use the tabs for Music, Timer, System and Activity. The bell opens Notifications, the monitor opens desktop shortcuts, and the sliders icon opens Settings. Escape returns from Settings or another tab to Music, then closes; × always closes. Keyboard summons support Tab navigation and outside-click dismissal.

Hide-idle hides the pill only when there is no player, timer, activity, notification preview or enabled system banner. A paused player counts as present. A hidden Perch can always be summoned outside fullscreen. The compact waveform is a static playback icon, not an audio-level visualizer.

## Send progress from a script or agent

No browser-download scraping is installed. Agent hooks are optional (below); any producer can also explicitly report its state:

```bash
omarchy-shell io.github.tcballard.perch activity '{"id":"build","title":"Building Perch","detail":"Running tests","state":"running","progress":0.65,"ttl":300}'
omarchy-shell io.github.tcballard.perch activity '{"id":"build","title":"Build complete","state":"done","progress":1}'
omarchy-shell io.github.tcballard.perch dismiss build
```

Updating the same `id` replaces that card. Up to eight cards are kept. IDs are 1–64 letters/digits/dots/underscores/hyphens and must start with a letter or digit. Titles are limited to 120 characters, details to 240, and each JSON payload to 4096 characters. All text renders as plain text.

`state` is `running`, `waiting`, `done` or `error`; `waiting` displays “Needs attention”. `progress` is 0–1, or omitted/−1 when unknown. `ttl` is 5–86400 seconds; the default is 300 seconds, or 30 for a completed card. Producers should refresh long-running cards before expiry. Activities are transient and clear on shell restart. They cannot execute commands, open links or grant agent permissions.

An optional Python 3 helper quotes JSON safely and applies a five-second IPC timeout:

```bash
~/.config/omarchy/plugins/io.github.tcballard.perch/scripts/perch-activity build \
  --title 'Building Perch' --detail 'Running tests' --progress 0.65
```

[`examples/build-with-perch.sh`](examples/build-with-perch.sh) wraps a command you explicitly run, reports success/failure, and preserves its exit status. It does not install hooks or change agent configuration.

Timer and diagnostics IPC:

```bash
omarchy-shell io.github.tcballard.perch timer 1500 Focus
omarchy-shell io.github.tcballard.perch cancelTimer
omarchy-shell io.github.tcballard.perch status
```

Starting a timer while one is running/paused is rejected. Status reports state/counts and device availability, not track metadata or activity text.

## State, dependencies and boundaries

Perch runs inside `omarchy-shell` with native MPRIS, PipeWire and UPower data. It has no external daemon or periodic subprocess polling. Short, serialized three-second CLI jobs carry notification events and explicit menu/actions; inbox synchronization runs once at startup and when opened/refreshed. Agent hooks have a one-second IPC deadline and discard output. Setup requires Python 3.11+; testing additionally requires Node and PySide6 Essentials 6.11.2.

Perch reads `~/.config/omarchy/shell.json` to find its own entry. It writes only its own preferences and timer state through Omarchy’s scoped settings API; it never rewrites the file itself. Timer transitions save state, not every tick. A missing/malformed settings file produces an error and blocks writes rather than resetting the user’s configuration. Settings over 1 MiB are rejected after reading; FileView itself reads the user-owned file before that check. No credentials are read or stored.

Timers use a saved wall-clock deadline so suspension and shell restarts count toward elapsed time. Changing the system clock can change the remaining time. Completion remains in the pill until dismissed; v0.1.0 has no audible alarm or desktop notification, and fullscreen suppression also applies to finished timers.

Artwork is local `file:///` metadata only, decoded at a bounded requested size. No remote artwork, HTTP calls, telemetry, agent execution or clipboard monitoring. The original bar, shortcuts and media keys remain in place; notifications remain built-in unless you opt into the companion. System banners may appear alongside Omarchy’s own OSD; they can be disabled in Settings.

## Optional notifications

```bash
cd ~/.config/omarchy/plugins/io.github.tcballard.perch
./scripts/perch-notifications-setup          # preview
./scripts/perch-notifications-setup --apply  # enable the companion
omarchy restart shell
```

Open the bell → Refresh. Notifications replace the built-in daemon using Omarchy's `clonedFrom` lifecycle; do not run another notification daemon alongside it. Setup refuses a competing enabled notification clone. After updating Perch, rerun this installer to update its separate companion copy, then restart the shell.

The inbox keeps the last **20 notifications in memory**; history and DND reset when the companion reloads. Text is plain and truncated (app 64, title 120, body 400 characters; four actions maximum). Previews last six seconds, respect DND and fullscreen suppression, and never steal focus. Default notifications expire after eight seconds; explicit timeouts are bounded to 1–30 seconds, while no-expiry/critical notifications remain live until dismissed or evicted. Expired history keeps text but no actions. Transient notifications leave no history after expiry. Sender replacements update the existing row.

Actions invoke only the live sender's native notification action. Inline replies, images, body links, executable hints and restored actions are not supported. Notification text passes through same-user shell IPC arguments, but is not written to disk. Turning on DND suppresses all previews, including critical ones. Perch's timer completion and activity attention remain separate from notification DND.

**Disable/remove the companion before disabling/removing Perch** so notifications have a visible owner:

```bash
./scripts/perch-notifications-setup --remove --apply
```

This restores the source through Omarchy; if it was disabled before installation, it stays disabled. To disable only, preserving the installed files: `omarchy plugin disable io.github.tcballard.perch-notifications`. If setup is interrupted, that command is also the recovery path. Companion files with local edits are never overwritten by setup.

## Optional agent hooks

```bash
cd ~/.config/omarchy/plugins/io.github.tcballard.perch
./scripts/perch-agent-setup claude --apply
./scripts/perch-agent-setup codex --apply
```

Omit `--apply` for a read-only preview. Restart the agent after setup. The installer uses user-level settings (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` when set), preserves unrelated settings and hooks, makes mode-600 dated backups beside modified config files, and installs a small adapter under `~/.local/share/omarchy-perch/`. It refuses to overwrite an existing Codex notifier or a modified Perch notify block. Claude JSON formatting may change; unrelated values are preserved. Managed hook restrictions and disabled-hook preferences are not overridden.

Claude Code sends working on prompt/tool completion, attention on permission/idle/elicitation notifications, and completion on Stop/SessionEnd. These are reported events, not an inferred process monitor; event support varies across agent clients. Working/attention cards expire after an hour without another event, completed cards after 30 seconds. Codex's supported `notify` contract reports **turn completion only**; it does not supply working or approval state. Oversized events above 64 KiB are ignored. Hooks always return silently and cannot approve, reject or alter an agent operation. Prompt text, transcripts, tool inputs, paths and credentials are never forwarded; session IDs are hashed for card identity.

Remove each integration before removing Perch (existing unrelated hooks remain):

```bash
./scripts/perch-agent-setup claude --remove --apply
./scripts/perch-agent-setup codex --remove --apply
```

After removing both integrations, the inert `~/.local/share/omarchy-perch/perch-agent-hook` file can be deleted. Dated config backups are retained for you to review/remove. Setup never reads agent credential files. For manual integration with an existing notifier, invoke `python3 ~/.local/share/omarchy-perch/perch-agent-hook --perch-hook-v1 codex "$event_json"` from your own notifier; Perch does not automatically chain existing commands.

Contracts: [Claude Code hooks](https://code.claude.com/docs/en/hooks), [Codex notify](https://developers.openai.com/codex/config-advanced#notifications), [Quickshell notifications](https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Notifications/Notification/).

## Disable or remove

```bash
omarchy plugin disable io.github.tcballard.perch
omarchy plugin remove io.github.tcballard.perch
```

On the inspected Quattro revision, disabling a third-party plugin removes its configuration entry, so **disable/remove clears Perch preferences and its timer**. Closing the panel or restarting the shell preserves them. Removal uses Omarchy’s plugin lifecycle; the core has no external daemon or keybinding to clean up. Remove optional integrations first using the commands above. A Git-managed install’s checkout is removed. A local symlink’s source remains yours.

If you installed the earlier unpublished `io.github.tcballard.omarchy-notch`, remove that registration before installing Perch. Its old source files remain yours.

## Demos and verification

From the checkout, run `./demo/run playing`, `paused`, `empty`, `timer`, `system`, `activity`, `inbox` or `desktop`. Demo playback, seeking, timer, audio and inbox controls use isolated fictional state. Preferences apply to the actual Perch placement/behaviour. Closing exits demo mode; it does not alter real playback or the real timer.

```bash
./tests/run
PYTHONPATH=/path/to/pyside6 python3 tests/render_preview.py preview.png Review.qml
```

`preview.png` renders the production QML with fixture data and theme stubs. It is not a desktop screenshot. Tests cover service/view behaviour, bounded IPC, seeking races, persistence failure, timer restoration, unavailable devices, keyboard/pointer controls and edge policy. They do not establish real compositor or DBus behaviour.

Target shell contract: Omarchy quattro `d3cfd53b997f8bdcf776b8db68bf0d735e7a065d`. See [TESTING.md](TESTING.md), [DESIGN.md](DESIGN.md) and [CHANGELOG.md](CHANGELOG.md) for evidence and release boundaries.

[Report a bug](https://github.com/tcballard/omarchy-perch/issues). Include the Perch commit, Omarchy revision and relevant Perch log lines. For sensitive security findings, open a minimal issue requesting a private contact channel; do not post credentials or exploit details publicly.

MIT. Original implementation by Tom Ballard. [Island](https://github.com/Guilhermerisu/island) and [Dynamic Island Pro](https://github.com/harshithnadig/omarchy-dynamic-island) informed the feature comparison; their code is not included. A full replacement bar/tray, remote artwork and automatic browser-download detection remain outside v0.1.0. Desktop menus are accessed through supported Omarchy commands; the inbox and supported agent hooks are included as optional integrations.
