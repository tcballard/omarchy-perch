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
