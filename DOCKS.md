# Dock layouts

Open **Dock editor** from Settings or the profile name in the expanded header.
Perch keeps its native Omarchy surface and existing cards, with Dockset-style
layout controls. The [comparison checklist](GAPS.md) distinguishes implemented
features from platform differences and work still outstanding.

## Build a dock

The **Library** adds tools, installed applications, files, folders, HTTP(S) links,
installed-plugin launchers and spacers. Folder tiles open their browser; the
context menu can open them in the file manager. Application tiles use installed
desktop entries and theme icons. Perch never executes a command embedded in a
backup or link.

**Layout** switches between the contextual Notch and the persistent Dock,
controls scale and auto-hide, and chooses compact or wide tiles. Drag to reorder,
use Ctrl+arrow on a focused tile, or use the row controls. A dock holds up to 24
items; overflowing docks scroll on all four edges. Running windows are optional.
Auto-hide leaves a small edge handle; hover or click to open. Existing monitor,
edge, theme, reduced-motion and fullscreen preferences still apply.

**Profiles** saves up to 12 named layouts. Changes save to the active profile.
Start from Everyday, Building, Presenting or Wellbeing, then edit freely.
Ctrl+PageUp / Ctrl+PageDown switches profiles while Perch has keyboard focus.
Optional weekday/time schedules use local time, checked every 30 seconds. The
first matching profile wins, and stays selected when its interval ends. Manual
switches are respected until the next schedule match changes. Profiles contain
layout and weather preferences, not timers, reminders, account credentials or
notification history. They do not restore application windows.

**Backup** exports versioned JSON via copy/paste or a `.perch.json` file. Import
requires an explicit Replace profiles action. The portable file-dialog path is
limited to 50,000 text characters; large backups can use the text interface up to
128 KiB. Keep a backup before replacing a collection. Credential paths and keys
are excluded. Only one dock/profile is active at a time.

## Cards

- **Reminders:** local named lists, completion, reopening, undo and removing
  completed entries. Up to 256 entries. No cloud task-account synchronization.
- **Hydration:** 5–240 minute reminder interval, optional volume and local history,
  today's totals, delete/undo. A due reminder appears in the contextual Notch;
  it does not send an unsolicited desktop notification. Up to 2,048 history rows.
- **Windows:** list and focus verified Hyprland windows. Optional previews use
  Quickshell's compositor capture API and remain in memory. Refresh captures a
  new frame. The Minimize/Restore request depends on compositor support; Hyprland
  may ignore it. Disable previews if your capture protocol is unavailable.
- **Stats and storage:** CPU/per-core load, RAM, swap, memory pressure, load
  averages, uptime, root-disk use and 30 in-memory CPU samples. Scan an explicitly
  selected folder to see its largest children. Scans stop at 20,000 entries,
  64 levels or four seconds; incomplete results are marked partial. Sizes use
  allocated blocks; symlinks are skipped. No cleanup/delete operation.
- **Trash:** count the user's home Trash and open it in the file manager. Mounted
  volume trash is not counted. Perch does not empty the Trash.
- **Weather:** city search, hourly forecast, Celsius/Fahrenheit and up to four
  additional independently configured locations. Searching sends the query to
  Open-Meteo; enabling a location sends its coordinates for forecasts.
- **AI usage:** existing Codex/Claude allowance sources plus local daily activity
  charts. Charts scan bounded metadata from their local session logs, never
  display prompts, and are not account-wide billing totals. Truncation is marked.
- **Business:** read-only Stripe, Paddle or Shopify metrics and daily charts.
  Up to 12 named accounts and eight independent tiles, guided setup, reporting
  comparisons and persistent Stripe history. See [BUSINESS.md](BUSINESS.md) for
  setup and exact metric definitions.

Existing music, ICS calendar/meetings, timers, file shelf, clipboard, device
controls, notifications and agent activities remain available in the Library.

## Validation boundary

Production QML tests use host/compositor stubs. They verify component loading,
profile persistence, failure handling, narrow layouts and hidden-state polling.
Actual window capture, native dialogs, pointer regions, scaling, focus release
and display changes require a live Omarchy session. Provider transports and
calculations have fixtures, but no real business account was connected here.
