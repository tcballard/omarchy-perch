# Verification — 29 September 2026

## Completed in the build environment

- `./tests/run` with Python 3, Node and PySide6 Essentials 6.11.2: passed.
- `tests/test_policy.cjs`: player selection, disappearing/preferred players, proxy exclusion, capability gating, metadata bounds, local-art URL policy, progress/time formatting, malformed and oversized summon payloads.
- `tests/test_lifecycle.cjs`: executes the actual Panel.qml lifecycle methods in a simulated host; repeated opens, focus prime, pointer mode, timer cleanup, malformed payloads, own host hide and fullscreen suppression.
- `tests/test_qml.py`: actual Service.qml and NotchView.qml under native Qt with fake MPRIS/IPC and theme modules. Playback selection, actions, no action when unsupported, removal, reactive changes, empty state, Escape and session preferences passed without Qt warnings.
- Toolkit portable validator with `--security`: no errors or advisory findings. The capability scan flags the CI-only pip installation for review; it does not run during plugin installation or runtime. This is static guidance, not security certification.
- Qt 6.11.2 `qmlformat` parsed every production QML file.
- `tests/render_preview.py`: actual QML render with fictional media and theme stubs; visually inspected. Image is not live-shell evidence.

The exact production files and tests are included together in this archive. The source contract inspected was Omarchy quattro commit `d3cfd53b997f8bdcf776b8db68bf0d735e7a065d`.

## Required on the XPS before a release

1. Run `omarchy plugin validate` against the installed Quattro revision. Enable from a fresh local installation; check shell logs for load/import errors.
2. Play/pause in a real MPRIS player; verify metadata, skip, missing artwork, unknown duration and unsupported controls. Start another player, switch, close the selected player and verify recovery.
3. Hover then leave; click controls; summon twice; Escape and outside-click. Confirm an inactive notch never steals typing and focus returns after every close path, especially across monitors.
4. Verify placement with top/side/bottom bars, auto-hidden bars, 100/150/200% scaling and font-size changes. Resize/attach/detach displays. Default offset must clear the active top bar.
5. Enter fullscreen, switch workspaces, exit fullscreen and summon again. No stuck input regions or keyboard grab.
6. Demo controls must not affect live playback. Close demo and confirm live media returns.
7. Toggle session preferences. Hide idle, then summon to recover controls. Reload clears session preferences as documented.
8. Disable/re-enable, hot reload and remove the symlink. The original bar, media keys, notification service and bindings must be unchanged.

These compositor, real DBus and installed-host checks have not been run here. Do not tag a stable release or claim marketplace approval from the portable results.

## Four-edge update

Portable geometry tests cover all 16 edge/bar combinations, hidden bars and flush attachment. Native Qt tests verify compact and expanded dimensions on all four edges, upright controls and settings expansion. Lifecycle tests execute the production setEdge method to verify collapse, remap scheduling and focus release. Live acceptance must test all four edges, especially inward expansion and bar clearance.

## Startup fix — explicit Qt Controls imports

The XPS shell log reported `NotchView.qml: Cannot assign to non-existent property "checked"`. The unqualified settings Button resolved to `qs.Ui.Button`, whose API uses `selected`, rather than Qt Quick Controls Button. Qualifying the view's Qt controls removes the collision. The test host now includes a competing `qs.Ui.Button` without `checked` or `checkable`; the original view fails to load against it, while the corrected view passes. Live shell startup must still be confirmed on the XPS.

## Interaction rework — 29 September 2026

User confirmed the import fix made Perch visible, then reported poor appearance and responsiveness. The rework passes native Qt service/view tests (including an actual pointer click on playback, hidden transport in empty state, Settings/Escape, all four edge dimensions, and light/dark theme contrast), lifecycle and geometry tests, and QML formatting. Actual production view renders were reviewed in playing, empty, compact and settings states; `tests/Review.qml` produces the overview in `preview.png`.

The fixed compositor envelope and view-only animation remove per-frame window-size requests by construction. This is not a measured FPS/latency improvement: real Wayland input masking, hover transitions, outside-click focus, edge remapping and smoothness still require the XPS. Specifically verify that clicking the transparent area around a compact pill reaches the underlying app and that all four expansions remain anchored. No live performance claim is made.

## 0.1.0-rc.1 evidence

User confirmed the preceding interaction rework was much smoother on the XPS. New candidate tests pass locally using PySide6 Essentials 6.11.2, including:

- production Preferences own-ID persistence, unknown-key preservation, malformed input and failed-write behaviour;
- production timer start/pause/resume/cancel, no per-tick writes, saved-state restoration and expiry;
- bounded activity reports, replacement, limit eight, attention priority, expiration, invalid input;
- guarded seeking (capability, player and track changes), explicit raise, unavailable audio/battery;
- native Qt pointer clicks through Music/Timer/System/Activity, playback, settings/Escape, light-theme contrast and demo isolation;
- fixture-rendered overview including timer, system, activities and settings, inspected visually;
- Node policy/lifecycle tests and shell syntax checks.

The toolkit validator reports zero errors/warnings/security findings, with review-required capabilities for reading shell.json through FileView and CI-only pip installation. FileView reads before the 1 MiB parser limit; no producer-side read cap is claimed. Static checks are not a security audit. The release preflight’s packaged sibling-validator locator is absent in this environment; unchanged copies of the release and validator scripts are placed in their expected sibling layout for the preflight, without editing the installed skills.

### XPS checks before a stable v0.1.0 tag

1. Update from Git, validate the installed directory, and open every tab with no Perch log errors. Verify the new native service imports load.
2. Select a new edge and toggle settings; restart the shell and confirm persistence. Ensure unrelated shell.json entries remain intact.
3. Start a 60-second timer, pause/resume it, restart the shell while running, and confirm the original deadline finishes. Dismiss it. It is a visual timer: no audible alarm.
4. With a real MPRIS player, seek, change tracks during a drag, switch players, and click artwork to raise supported players. Unsupported actions remain unavailable.
5. Change volume/mute and plug/unplug power. Verify actual output/battery data and that disabling banners suppresses only Perch feedback.
6. Send the documented activity example, update the same ID, dismiss it and let a short TTL expire. No real agent hook is needed.
7. Repeat hover/click/Escape/outside-click and transparent-area click-through on all edges; test fullscreen and monitor removal. The fixed envelope is now taller for Settings.
8. Disable/re-enable then remove/reinstall through Omarchy. Confirm bar, notifications and keys remain intact. On the inspected host, disable removes the third-party entry: expect preferences/timer to reset on re-enable. Closing the panel and shell restart must preserve them.

No live claim is made for these new features until those results are reported. CI status and the final candidate SHA are recorded at publication.

Candidate preparation also passes the inspected upstream `omarchy-plugin-validate` command (manifest validation only) and the static release preflight using the unchanged scripts in the resolved sibling layout. Its advisory capability categories are the reviewed FileView read and CI dependency installation noted above. Full host validation is still pending.

The first candidate CI run exposed missing libEGL.so.1 on the Ubuntu runner before Qt tests could import. CI now installs libegl1/libopengl0 explicitly; the Qt tests remain required. This CI-only dependency setup does not run during plugin installation.


## 0.1.0-rc.2 evidence and live gate

Portable checks additionally cover notification IPC bounds and unique keys; production notification QML compiles against host stubs and exercises replacement signals, native action invocation, stale generation rejection, expiry, transient cleanup and DND. Pointer tests open the actual inbox/desktop buttons and invoke a fixture notification action through the production delegate. Isolated HOME tests exercise preview/no-write, idempotent install, owned removal, original notifier preservation, Claude unrelated settings/hooks, edited-file refusal, config backups, silence and status-only payloads. Both core and companion manifests are validated. These do not simulate DBus name ownership or prove actual agent-client event delivery.

Before stable v0.1.0 on the XPS:
1. Update core, restart and verify existing media/timer/audio and smooth four-edge reveal. Open bell/desktop with pointer and keyboard; Tab/Escape/outside click remain usable.
2. Preview/install notification companion; restart. Send `notify-send 'Perch rc2' 'Hello from the desktop'`, a critical notification, an explicit expiry, a transient notification and an action-enabled sender. Confirm one daemon owns notifications, one preview, correct text, DND, expiry and action cleanup. Verify sender replacement updates one row and a closed sender cannot be invoked.
3. Disable/remove companion while core remains enabled; verify built-in notification service returns. Repeat with the source previously disabled: it must remain disabled. Test interrupted setup recovery and competing notification clone refusal. Reinstall/update the separate companion and verify history/DND reset is clear.
4. Open Applications, clipboard, emoji, appearance and setup; confirm Perch releases focus and the destination gets it. No commands run just by showing the desktop page.
5. Preview/apply each installed agent's hooks. Preserve a preexisting Claude hook and verify both still run. Confirm actual Claude working → attention → working → complete and actual Codex turn completion. Use a preexisting Codex notifier to verify refusal, not replacement. Stop Perch and ensure hook failures do not break agent operations.
6. Remove agent hooks; compare configuration semantics with the backup, then remove companion before core. Check original notifications, bar, keys and agent behavior. Backups and adapter are deliberately retained; no automatic deletion of user-edited state.

The new integrations require these live checks; stable release remains gated.

rc2 static preflight flags the reviewed CLI Process helpers and opt-in setup scripts, alongside the existing FileView read and CI-only package installation. CLI runtime call sites use fixed command/verb allowlists and bounded payloads; one running job per helper, three-second deadline, 512-character retained reply. SplitParser reads output from trusted Omarchy CLI commands, not arbitrary producer subprocesses; no general producer-side stream cap is claimed. Setup scripts are explicit user actions, not plugin startup behavior.

## 0.1.0-rc.3 evidence and live gate

Portable tests now exercise durable reference-only shelf operations, private history with actions stripped on restore, malformed/oversized/symlink input rejection, ICS timezone/recurrence exclusions, lyrics, remote artwork URL restrictions, subprocess output/time limits, transfer limits/cleanup, command exit status/cancellation, concurrent timer state, mic capability, inline reply generation/expiry and monitor pin/fullscreen behavior. Production view rendering includes Files, Calendar, Setup and the expanded system controls. Tests use fake host/DBus objects; they do not claim real device operation.

Additional live acceptance:

1. Open Setup, enable/update each desired companion; reopen after reload. Verify one notification owner and one volume/brightness OSD. Prepare removal must restore the previous source state and preserve unrelated agent config. Restart the shell during setup and check its result afterward.
2. Drop real files, drag them into a supported app, preview text/images, reveal and hand off to LocalSend. Restart the shell: shelf persists and removing a shelf entry leaves the original intact.
3. Add a synced ICS file, test timezone/DST, moved/cancelled meetings, partial-recurrence warning, refresh and Join. Check compact imminent meeting context after startup and after the five-minute refresh.
4. Run eight timers, suspend/resume, trigger simultaneous completion and try sound/notifications, snooze/repeat and all fullscreen policies.
5. Switch real audio input/output, mute microphone, change brightness, connect/disconnect paired Bluetooth devices, inspect available battery data. Missing tools/hardware must show unavailable/error, never success.
6. Receive sender-supported inline replies/actions, close the sender, restart the companion, verify restored text has no live action. Check DND/mutes/unread and transient deletion.
7. Pin applications; use per-monitor settings at fractional scaling; disconnect/reconnect the pinned display; check every edge and transparent input region. Fullscreen default remains hidden.
8. Exercise local/remote art with slow and failed providers, track/player switches during requests, lyrics reader, cancelled tasks, interrupted transfers and process cleanup after shell reload.

### Performance measurements

Use `pgrep -af quickshell` to identify the actual hosting process, then substitute its PID:

```bash
./scripts/perch-diagnostics --pid 12345 --seconds 10
./scripts/perch-diagnostics --pid 12345 --seconds 10 --exercise
```

Run an idle sample before/after feature use, and repeat after 100 open/close interactions. The JSON reports **whole-shell** CPU/RSS and optional summon IPC round-trip times, not Perch-only usage or frame latency. Compare the same workload and shell revision. Look for accumulating RSS, unexpected idle work, lingering helpers and unbounded retries. Assess actual animation frame pacing with a compositor profiler/recording on the XPS; no portable timing number substitutes for this. The runner does not collect notification text, paths, logs or credentials.

Live results for rc3: **not run in the build environment**. Stable tagging remains gated on the above.

Static rc3 release review: upstream host validator accepts core and both companions. Advisory scan flags QML processes/collectors, explicit setup scripts and CI package installation. ToolJob collects only the shipped helper's capped 128 KiB JSON with a 12-second deadline; history reads cap before collection and writes use bounded stdin. Setup commands are explicit, own-file hash checked and time-bounded. CI package installation is not plugin runtime behavior. Existing Preferences FileView's read-before-limit boundary is documented above. No advisory scan is described as a security certification.

## 0.1.0-rc.4 evidence and live gate

Reviewed rc3 against the outstanding acceptance areas without XPS access. One defect was reproduced under native Qt with the production view: with any dropdown open, the view's HoverHandler reports not hovered while the pointer is on the popup (the popup lives in the window overlay, outside the masked item). In pointer mode the 220 ms leave grace would therefore collapse Perch and close the dropdown, and popup rows outside the item rectangle were outside the compositor input region. The fix reports popup state from every dropdown, adds the overlay to the input mask only while a popup is open, holds the leave grace, and closes a dropdown when its view collapses or is disabled. Native Qt tests now assert the popup report and its reset on collapse. Real Wayland input-region behaviour still requires the XPS.

Also fixed from review: helper jobs queue instead of failing on collision (calendar refresh, health poll, brightness read and drop-then-refresh could all collide); artwork refetch on every own-entry write; meeting summaries taken over by all-day or long-running entries; inbox failure text without the companion; missing-tool errors; setup failures losing their reason; no indication that companion copies lag a core update. Isolated-HOME tests exercise drift detection and a failing worker step; the rc2 fake `omarchy` commands remain fakes.

Environment: Python 3.11.15, Node 22, PySide6 Essentials 6.11.2 with Qt offscreen; `./tests/run` passes in full, including the Qt tests. `qmlformat` was not available here; edits follow the existing formatting by hand.

Additional live checks for rc.4 on the XPS, in addition to the rc.3 list:

1. With hover opening on, open the output device dropdown on System and the timer picker; move the pointer over the rows and pick one. Perch must stay open and the choice must apply. Repeat for a dropdown whose rows extend past the notch chrome (Settings → During fullscreen near the bottom).
2. After a keyboard summon, open a dropdown and click outside Perch: both the dropdown and Perch must close and focus must return.
3. Update the core, open Setup: an enabled companion should read “installed copy is older than this Perch version” with “Update now”. Run it, restart the shell, reopen Setup: the mark clears and one notification owner / one OSD remain.
4. Disable Perch in `shell.json` and press Enable for notifications: the job must fail with the “Enable Perch before…” reason shown in Setup, and nothing else must change.
5. Add an ICS containing an all-day entry and a timed meeting: the compact pill shows only the timed countdown; the agenda lists both.

Live results for rc.4: **not run in the build environment**. Stable tagging remains gated.

## 0.1.0-rc.5 evidence and live gate

Polish on the confirmed base: Hyprland global shortcut (`perch:toggle`), page/context enter transitions, compact artwork, whole-card shelf drag and deferred timer alerts. Native Qt tests assert that a page change animates and settles to exactly zero offset, that a page set while collapsed leaves no offset (a static render exposed that case), that reduced motion settles instantly, and that a timer which ran out within the last 15 minutes alerts once on restore while an older one does not. The lifecycle test executes the production `toggle` through the host summon/hide path. Nothing here changes the compositor surface, mask or the 140/90/220 ms timings.

Live checks for rc.5 on the XPS:

1. Add `bind = SUPER, P, global, perch:toggle` to Hyprland, reload, press it: Perch opens on the focused display with keyboard focus; pressing again closes it; Escape and outside click still work. Check `hyprctl globalshortcuts` lists it once.
2. Switch tabs and open Settings with reduced motion off, then on: the 140 ms slide/fade must not stutter or leave content offset; the compact pill transition must not fire on countdown ticks.
3. Play a track with local artwork, then one without: the compact pill shows the cover, then the icon.
4. Drag a shelf card into a file manager and a browser; click each card button; both must work.
5. Start a one-minute timer, run `omarchy restart shell` after it ends but within 15 minutes with sound/notification enabled: one alert; repeat after 15 minutes: none.

A second adversarial pass over the helper scripts (isolated HOME, fake `omarchy` commands) found and fixed: recurrence expansion proportional to the age of a series, which put a realistic Google export past the 12 s helper deadline on add; quoted and Outlook timezone IDs dropping events; `DURATION` ignored; alarm properties merged into events; brightnessctl selecting a keyboard LED when no backlight exists; a first companion install leaving its copy behind when enable failed; previews refusing files over 64 KiB; `perch-task run` detaching from the terminal; hard-link publication failing on vfat; a corrupt job file crashing health. All have tests in `tests/test_rc3.py` and `tests/test_rc2.py`. The same pass verified store locking under concurrent writers, transfer cleanup, redirect handling and hook silence as correct.

Additional rc.5 live checks: add a real Outlook or Google export with old weekly series and confirm the agenda appears within a second and the Setup brightness line reads “available” only on the XPS panel, not a keyboard LED.

Live results for rc.5: **not run in the build environment**.
