# Perch

[![Built for Omarchy: Plugin](https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg)](https://github.com/tcballard/omarchy-badges)

Music, files, meetings, timers and live progress at any edge of your Omarchy desktop. A small pill opens into the controls you need, then gets out of the way.

**v0.1.0-rc.4 — release candidate.** rc.3 added contextual controls, files, calendars, multiple timers, richer system controls and guided setup; rc.4 fixes dropdown input/hover handling, serializes helper jobs, detects outdated companion copies and reports which setup step failed. Portable tests and actual QML fixture rendering pass. The hardware/compositor integrations still need the XPS checks in [TESTING.md](TESTING.md); this is not a stable release or a claim of macOS feature parity. [Scope and boundaries](GAPS.md).

![Perch’s actual QML views with fictional media, timer and activity fixtures](preview.png)

## What you get

- **Context at the edge:** direct play/pause or timer actions, wheel cycling between concurrent activities and header swipe navigation. Four edges, monitor pinning, per-display width/offset/edge/fullscreen preferences, reduced motion.
- **Music:** native MPRIS controls, seeking, player selection, local artwork, optional bounded HTTPS artwork, local `.lrc` synchronized lyrics and a full lyrics reader.
- **File shelf:** up to 32 persistent file/folder references, drag in/out, small text/image previews, open, reveal and LocalSend handoff. Removing a reference never deletes its original.
- **Meetings:** agenda, imminent meeting countdown and explicit Join from up to eight local `.ics` files, including files maintained by a calendar sync tool. The compact countdown covers the 15 minutes before a timed meeting and its first 10 minutes; all-day entries stay in the agenda only.
- **Timers:** up to eight named timers, pause/resume/cancel, repeat, snooze, optional completion sounds/desktop notifications. Wall-clock deadlines survive suspension and shell restart.
- **System:** output/input selection, volume/mute, microphone mute, battery, paired Bluetooth connect/disconnect and battery status, optional brightnessctl. Missing capabilities are shown explicitly.
- **Notifications (opt-in):** persistent 20-item history, unread markers, app filtering/muting, DND, icons, native actions and sender-supported replies. A companion replaces the built-in notification owner while enabled.
- **Applications:** six Omarchy shortcuts, installed-app picker and up to eight pins.
- **Live activities:** bounded IPC, real build/download/copy adapters, Claude Code status hooks and Codex completion hooks.
- **Setup:** integration status, explicit enable/disable, optional system-feedback companion to replace stock OSD, dependency reporting and coordinated integration removal.

The compact view prioritizes completion/attention, notification previews, system feedback, timers, imminent meetings, other activities, music and the clock. It does not automatically expand or take keyboard focus. Fullscreen defaults to hidden; Settings also offers completed-timer alerts or always show.

## Install or update

Requires Omarchy Quattro’s plugin-capable shell with the scoped `updateEntryInline` API, QtQuick Controls/Layouts, Quickshell MPRIS, PipeWire, Bluetooth, UPower, IO, Wayland and Hyprland modules, plus Omarchy’s `qs.Commons` and `qs.Ui` modules. These are provided by the target shell; a media player must expose MPRIS for music controls.

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

`page` accepts `music`, `timer`, `system`, `activity`, `players`, `inbox`, `desktop`, `hub`, `shelf`, `calendar` or `setup`. Hover opening stays on the hovered display. Keyboard summons select the focused display unless a monitor is pinned in Settings. Startup uses the first display; unplugging it falls back to an available display.

## Controls

Hover for 90 ms or click the pill to open. Expansion animates the visible item for 140 ms inside a stable compositor surface. A 220 ms leave grace lets you move between controls. Disable hover opening to require a click; reduced motion disables expansion/fade animation.

Use the tabs for Music, Timer, System and Activity. The bell opens Notifications, the monitor opens the hub for Files, Calendar, Applications and Setup, and the sliders icon opens Settings. Escape returns from Settings or another tab to Music, then closes; × always closes. Keyboard summons support Tab navigation and outside-click dismissal.

Hide-idle hides the pill only when there is no player, timer, activity, notification preview or enabled system banner. A paused player counts as present. A hidden Perch can always be summoned outside fullscreen. Scroll the compact pill to cycle contexts; swipe horizontally across the left side of the header to change pages. The compact waveform is a static playback icon, not an audio-level visualizer.

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

The legacy timer IPC rejects replacement of a running/paused selected timer. Use New timer in the UI to add concurrent timers. Status reports state/counts and device availability, not track metadata or activity text.

## State, dependencies and boundaries

Perch runs inside `omarchy-shell`. Native media/device changes are event-driven. Bounded Python jobs handle file/calendar/app operations and explicit integration setup. Configured calendars refresh every five minutes; Setup polls every three seconds only while a setup job is running. Helper operations run one at a time and queue briefly behind each other. No general process or browser polling runs at idle. Python 3.11+ is required; optional features use `brightnessctl`, the LocalSend GUI (`localsend` or `localsend_app`), `canberra-gtk-play`, `notify-send`, `gtk-launch` and `xdg-open`. Nothing is installed automatically.

Settings, pins, display profiles and timer transitions use Perch's own `shell.json` entry through the scoped host API. Unknown own-entry keys are retained. Bad settings block writes. FileView reads the user-owned shell settings before applying its 1 MiB parse limit. Timers save on transitions, not every tick; changing the system clock affects their deadlines.

Shelf references, calendar source paths and notification history/DND/mutes live in private `$XDG_STATE_HOME/omarchy-perch` (default `~/.local/state/omarchy-perch`). This includes notification text and file paths; there is no telemetry. State remains after plugin removal so uninstall does not silently destroy user data. Delete that directory yourself if you want to erase retained data. Restored notifications have no executable actions or replies.

Remote artwork is off by default. When enabled, Perch fetches HTTPS URLs supplied by your media player: public addresses only, validated redirects, seven-second deadline, 2 MiB image limit and bounded dimensions. At most 32 covers are cached under `$XDG_CACHE_HOME/omarchy-perch`. Local previews and artwork still use Qt's decoders; this is not a hostile-image sandbox. Lyrics are explicitly chosen local UTF-8 `.lrc` or `.txt` files; no lyrics service/account is contacted.

Calendar support is read-only ICS, not Google/Microsoft/iCloud account login. Daily/weekly recurrence, timezone IDs, exclusions and moved/cancelled instances are supported. More complex recurrence is reported as partial rather than guessed. Agenda files are limited to 1 MiB each, 2,000 source events, 60 displayed occurrences and a 30-day window. Join opens an HTTP(S) link from the current agenda after a click.

## Guided setup and task adapters

```bash
omarchy-shell shell summon io.github.tcballard.perch '{"page":"setup"}'
```

Enable only the integrations you want. Setup is explicit and may reload Perch while Omarchy discovers a companion. Reopen Setup to see the durable job result, which names the step that failed if one did. After updating the core, Setup marks enabled companions whose installed copy differs from the checkout; use Update now to copy the new version, then run `omarchy restart shell`. Local edits are protected. **Prepare removal** removes owned agent hooks and companions before removing the core; it preserves unrelated configuration and restores source plugins according to Omarchy's clone lifecycle. If a step fails, resolve it before uninstalling Perch.

The new task adapter runs only the command or transfer you supply, inherits build output, preserves command exit status, throttles progress, and cleans up partial transfers on cancellation. Downloads/copies default to a 1 GiB cap and one-hour deadline; existing destination files are never overwritten.

```bash
cd ~/.config/omarchy/plugins/io.github.tcballard.perch
./scripts/perch-task --title 'Build' run -- make
./scripts/perch-task --title 'Download' download https://example.org/archive.zip "$HOME/Downloads/archive.zip"
./scripts/perch-task --title 'Copy' copy "$HOME/report.pdf" "$HOME/Backups/report.pdf"
# Explicit Omarchy task wrapper; the command retains its normal prompts/permissions:
./scripts/perch-task --title 'Omarchy update' run -- omarchy update
```

This does not intercept existing browser downloads or infer arbitrary application's progress. Unknown build progress is shown as indeterminate until the command exits.

## Optional notifications

```bash
cd ~/.config/omarchy/plugins/io.github.tcballard.perch
./scripts/perch-notifications-setup          # preview
./scripts/perch-notifications-setup --apply  # enable the companion
omarchy restart shell
```

Open the bell → Refresh. Notifications replace the built-in daemon using Omarchy's `clonedFrom` lifecycle; do not run another notification daemon alongside it. Setup refuses a competing enabled notification clone. After updating Perch, rerun this installer to update its separate companion copy, then restart the shell.

The inbox retains the last **20 non-transient notifications** in private local state; DND and muted app names also survive companion reloads. Text is plain and truncated (app 64, title 120, body 400 characters; four actions maximum). Previews last six seconds, respect DND and fullscreen suppression, and never steal focus. Default notifications expire after eight seconds; explicit timeouts are bounded to 1–30 seconds, while no-expiry/critical notifications remain live until dismissed or evicted. Expired history keeps text but no actions. Transient notifications leave no history after expiry. Sender replacements update the existing row.

Actions and inline replies target only the live sender and are invalidated on expiry/closure. Replies appear only when the sender advertises that capability. Theme icons are supported; arbitrary images, body links, executable hints and restored actions are not. Notification text passes through same-user IPC and is persisted locally unless transient. Turning on DND suppresses all previews, including critical ones. Perch's timer completion and activity attention remain separate from notification DND.

**Disable/remove both companions before disabling/removing Perch** so notifications have a visible owner:

```bash
./scripts/perch-notifications-setup --kind osd --remove --apply
./scripts/perch-notifications-setup --remove --apply
```

The system-feedback companion uses the same installer with `--kind osd --apply`, replacing `omarchy.osd` instead of displaying a second overlay. This restores the source through Omarchy; if it was disabled before installation, it stays disabled. To disable only, preserving the installed files: `omarchy plugin disable io.github.tcballard.perch-notifications`. If setup is interrupted, that command is also the recovery path. Companion files with local edits are never overwritten by setup.

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

On the inspected Quattro revision, disabling a third-party plugin removes its configuration entry, so **disable/remove clears Perch preferences, pins, display profiles and timers**. Closing the panel or restarting the shell preserves them. Removal uses Omarchy’s plugin lifecycle; the core has no external daemon or keybinding to clean up. Remove optional integrations first using the commands above. A Git-managed install’s checkout is removed. A local symlink’s source remains yours.

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

MIT. Original implementation by Tom Ballard. [Island](https://github.com/Guilhermerisu/island) and [Dynamic Island Pro](https://github.com/harshithnadig/omarchy-dynamic-island) informed the feature comparison; their code is not included. A full replacement bar/tray, proprietary Apple continuity, account calendar sync and automatic browser-download detection remain outside this candidate; Linux alternatives and exact limits are listed in GAPS.md. Desktop menus are accessed through supported Omarchy commands; the inbox and supported agent hooks are included as optional integrations.
