# Native Perch modules

The **Module strip** puts up to eight chosen tools at the screen edge and is
Perch’s only layout. Saved pill configurations automatically use the strip.
Choose modules in Perch Settings. Drag tiles to reorder them, use Ctrl+arrow keys on a
focused tile, or use the earlier/later buttons in Settings. At least one module
stays selected. Unknown/duplicate saved IDs are discarded; an empty/invalid
selection restores the defaults.

Hover a tile for 150 ms (when Open on hover is enabled), or click it to open its
card. Expanded cards retain a horizontal strip for switching tools. The compact
strip follows the chosen screen edge, with upright labels on left/right edges.
The strip remains a launcher; old hide-idle and idle-clock settings are ignored.
Fullscreen and monitor policies still apply.

## Contract

`PerchModule.qml` is a native QML descriptor:

- `moduleId`, `title`, `compactText`, `status`;
- `state`: shared service-owned data;
- `card`: trusted QML Component for the expanded card;
- optional `settings`: trusted QML Component;
- `actions`: bounded built-in action identifiers and labels.

`ModuleCard.qml` supplies consistent chrome, card/settings switching, themed
`ink`/`surface` bindings and action dispatch. `ModuleRegistry.qml` wires the
all tools through this contract. `BuiltinCards.qml` supplies the existing music,
timer, device, file, calendar, activity, inbox and app views plus the player,
lyrics, setup and All tools subpages. Only the selected card is instantiated;
shared state stays in the service when cards unload. All tools remain reachable
through the hub even when omitted from the strip.

To add a built-in module: add its ID/label to ModulePolicy, a PerchModule descriptor
and Components to ModuleRegistry, and service-owned state if needed. Register
its page with Panel's summon allowlist and provide fixture/test coverage.
Preferences and incoming IPC cannot supply component paths, QML or commands.
There is no external module loader, new marketplace, Bun runtime or TSX SDK.
Perch still runs within Omarchy's one shell process. Built-in QML is trusted code,
not sandboxed code.

## Clipboard

Reads Omarchy's existing `~/.local/state/omarchy/clipboard-history.json`; it does
not capture, duplicate, rewrite, delete or persist history. Supports the current
text/image schema, classifying HTTP(S) text as links and file-URI text as files.
Search scans the first 8,192 characters of each of the first 500 source entries;
results show at most 50 previews of 160 characters, filtered by type.

Select an entry to copy it, then paste in your application. Search supports
Down to the results and Return to copy; the results support arrow navigation.
Selection uses a content-derived ID and resolves the entry again before copying,
so inserts/reordering cannot silently select another item. Deleted entries return
an error. Clipboard text is passed via stdin to `/usr/bin/wl-copy`, never argv.
The successful selection owner must outlive the helper; failed/timed-out owners
are terminated. No automatic typing/pasting into applications occurs.

Reads are capped before JSON parsing (4 MiB); image copy is capped at 8 MiB and
supports PNG/JPEG/WebP. Missing/oversized history and unavailable Wayland copy
produce visible errors. The built-in Omarchy Clipboard remains the place for
full image previews, deletion and larger histories. This module shows image
metadata, not image thumbnails. It refreshes every three seconds only while the
card is visible; results are cleared from module state when the card closes.

## Stats

Reads Linux `/proc/stat`, `/proc/meminfo` and root-filesystem usage through the
existing isolated Python helper. CPU uses deltas between samples; the first
sample displays Measuring rather than a fabricated zero. Memory uses
MemAvailable; storage is the `/` filesystem. Thirty CPU samples are kept in
memory only. Sampling runs at 2, 5 or 10 seconds (default 5), only while the stats
tile or card is visible. Fullscreen suppression stops sampling. A running bounded
read may finish after hiding. No process inspection or process control is added.

## Weather

Disabled until a user saves a location label and latitude/longitude with
**Save & enable**. The configured coordinates are sent to the fixed HTTPS
`api.open-meteo.com/v1/forecast` endpoint. No geolocation, account, API key or
location search. Current temperature, condition, wind and six hourly temperatures
use Celsius and km/h. Attribution: Open-Meteo, CC BY 4.0.

`/usr/bin/curl` is optional: its absence appears as unavailable weather. Requests
have a seven-second curl deadline, eight-second helper command deadline and
64 KiB receive limit; redirects are not followed. Updates occur every fifteen
minutes while the tile/card is visible, or on explicit Refresh. Changing location
invalidates old results and ignores late replies for the previous location.
Disabling stops future requests; an already-started bounded request may finish.
Previous data is explicitly marked when a refresh fails. Configuration persists
in Perch's own shell entry; fetched weather is in memory only.

The UI, module contract and state are QML/JavaScript. OS/network adapters use
Perch's existing bounded Python helper mechanism. No Sidedoor code is included.

## Verification

`./tests/run` includes registry sanitation, clipboard history races and limits,
weather endpoint/data validation, actual Linux stats sampling and production QML
clicks, search/copy, card/settings switching, keyboard/drag ordering, four-edge
geometry and visibility-driven sampling bindings. `tests/ModulesReview.qml`
renders production views with fictional data. `modules-preview.png` is that
fixture render, not an Omarchy screenshot.

Still requires a live Omarchy session: Wayland clipboard ownership after helper
exit, typing-focus return, hover switching/dragging on each edge, display scaling,
fullscreen suppression, and actual weather connectivity. No stable release or
performance claim follows from portable tests alone.
