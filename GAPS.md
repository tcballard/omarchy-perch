# Gap audit — rc.5 plus unreleased native modules

Every comparison category has an implementation or an explicit platform boundary. This is not a claim that Perch now equals every macOS notch app. Feature presence and actual desktop acceptance are separate.

| Category | Implemented in this candidate | Remaining boundary / live gate |
|---|---|---|
| Compact UX | Context priority, direct actions, wheel context cycling, header swipe, stable-surface animation | Real input-region, scaling and frame smoothness on XPS |
| Files | Persistent reference shelf, drag in/out, text/image preview, open/reveal, LocalSend handoff | App-specific Wayland drag interoperability; no AirDrop/Quick Look framework |
| Setup/lifecycle | Health/dependency page, explicit integration enable/disable, durable setup job, coordinated removal | Host cannot automatically run our cleanup on arbitrary core removal; use Prepare removal first |
| Notifications | Durable history/DND/mutes, unread state, app filter, theme icons, native actions, supported replies | Sender must support replies; native DBus ownership and restore need live acceptance |
| Devices/system | Audio output/input selection, mic mute, battery, paired Bluetooth controls/status, brightness, optional replacement OSD | Hardware capabilities vary; no Apple private AirPods/Continuity APIs |
| Calendar | Local/synced ICS agenda, meeting countdown, Join, timezone-aware daily/weekly recurrence and exceptions | Account OAuth/sync is external; complex recurrence is reported partial |
| Music | MPRIS seek/player controls, optional bounded remote covers, local synchronized lyrics/reader | Player capabilities vary; no lyrics-provider account or audio visualizer |
| Timers | Eight named timers, persistence, repeat/snooze, sound/notification options, fullscreen policy | Wall-clock changes matter; sound requires helper; suspend/device checks live |
| Activities | Build command, byte-progress download/copy adapters; project-labelled agent sessions, attention queue and Hyprland window return | Explicit producer jobs; no automatic browser-download interception; Codex completion-only; no approval response bridge |
| Displays | Pinned/focused monitor, per-display edge/width/offset/fullscreen settings | One surface on one selected monitor; unplug/DPI/compositor behavior live |
| Applications | Installed application picker, eight pins, supported desktop menus | Desktop entries depend on installed apps; no arbitrary shell commands from incoming activity data |
| Evidence/performance | Production QML tests/render, bounded helper tests, lifecycle tests, diagnostics runner | No invented FPS, battery-life or latency numbers; whole-shell diagnostics need real session |

## Candidate acceptance

Portable suite and fixture render pass. `TESTING.md` records the live checks still required. A successful helper or Qt fixture is not proof of actual Bluetooth, portal drag/drop, notification ownership, or compositor smoothness. Keep the release candidate label until these pass on the intended desktop.

## Unreleased Sidekick/Sidedoor comparison work

Implemented: single reorderable module strip, native card/settings/actions
contract, clipboard history browser/copy, compact CPU/RAM/root-disk stats, and
opt-in weather. All existing tools and secondary pages use the shared card host. No external widget loader or new
runtime. Remaining: image clipboard thumbnails, in-Perch history deletion,
first-class URL pins, per-item shortcut recorder, AI usage/quota integrations,
and hardware/compositor acceptance. See MODULES.md for exact supported limits.
