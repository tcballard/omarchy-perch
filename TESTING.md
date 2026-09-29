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
