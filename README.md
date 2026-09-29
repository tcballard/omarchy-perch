# Perch

[![Built for Omarchy: Plugin](https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg)](https://github.com/tcballard/omarchy-badges)

A quiet, expanding music notch for Omarchy. See what's playing, open the controls, and get back to your work.

**0.1.0-dev — development preview.** Implemented and tested with portable checks and Qt host stubs. Not yet verified in a live Omarchy session or submitted to the marketplace.

![Production QML rendered with fictional media and theme stubs](preview.png)

## What it does

- Choose **top, bottom, left or right** in the gear menu. Hover briefly or click to expand inward.
- Top/bottom use a horizontal pill; left/right use a slim upright tab. Expanded controls stay upright.
- Native MPRIS play/pause, previous/next and player switching, gated by each player's capabilities.
- Track and artist, player identity and progress when the player supplies timing.
- Local album artwork with a music-glyph fallback. Remote artwork is not fetched in this preview.
- Escape or × to collapse. Pointer-opened panels collapse after the pointer leaves; keyboard-opened panels use an outside-click focus grab.
- Hide-idle, reduced-motion and screen-edge preferences for the current shell session.
- Fullscreen suppression, theme colours and scaled typography.

The original bar stays active. Nothing changes your shortcuts, notification service or media-key configuration. The compact activity dot indicates playback; it is not an audio visualizer.

## Upgrading the earlier Omarchy Notch preview

This unpublished preview is now Perch, with plugin ID `io.github.tcballard.perch`. If you installed the earlier preview, first run `omarchy plugin remove io.github.tcballard.omarchy-notch`, then install Perch below. The old source files remain yours.

## Try the development preview

Requires Omarchy Quattro's plugin-capable shell, Quickshell with QtQuick Controls, MPRIS, Wayland and Hyprland modules, and the shell's `qs.Commons` and `qs.Ui` modules. Use any MPRIS-compatible media player. No playerctl, network service, credential or additional polling process is used.

Install the development version from GitHub:

```bash
omarchy plugin add https://github.com/tcballard/omarchy-perch.git --enable
```

This installs the current development branch, not a stable release. For an existing Git installation:

```bash
omarchy plugin update io.github.tcballard.perch
```

If you installed the earlier local Perch symlink, remove that registration with `omarchy plugin remove io.github.tcballard.perch` before adding the Git repository. Your extracted source remains in place.

Open from the terminal (or bind this command yourself):

```bash
omarchy-shell shell summon io.github.tcballard.perch
```

It opens on the focused monitor. At startup the compact surface uses the first screen; it stays on its selected monitor until summoned elsewhere. The panel stays hidden on fullscreen workspaces, including explicit summons in this first preview.

Stop it:

```bash
omarchy plugin disable io.github.tcballard.perch
```

Remove the plugin:

```bash
omarchy plugin remove io.github.tcballard.perch
```

Git-managed removal deletes the installed checkout; symlink removal leaves its source in place. Preferences and player selection are session-only and reset on reload; no plugin-owned durable data needs cleaning up.

## Controls and preferences

Click ↻ to cycle available players. A manually chosen player stays selected even if another starts playing; when it disappears, selection returns to an available playing player. Unsupported actions are disabled.

The gear opens the four-edge selector and three session preferences. Selecting a new edge collapses and remaps the surface. **Screen edge** attaches the surface flush to the selected edge and may overlap a bar on that edge; the default clears a visible bar on the same edge. **Hide idle** hides the compact surface when no player is available. **Reduce motion** disables expansion animations. Fullscreen remains unobstructed.

## Honest demos

With the plugin enabled, run `./demo/run playing`, `./demo/run paused`, or `./demo/run empty`. The header says **DEMO** and all controls act on fictional local state. Closing returns to real media. Demo controls never change a real player.

## Compatibility and checks

Target contract: Omarchy `quattro`, inspected at `d3cfd53b997f8bdcf776b8db68bf0d735e7a065d` on 29 September 2026. No release-wide support claim yet. Edge choice and other preferences remain session-only.

```bash
./tests/run
```

Portable checks require Python 3 and Node. Installing `PySide6-Essentials==6.11.2` enables production QML service/view tests with explicit host stubs. CI installs it; local runs clearly report its absence. Those tests do not verify Wayland placement or actual DBus/compositor behaviour.

See [TESTING.md](TESTING.md) for exact evidence and live acceptance, and [DESIGN.md](DESIGN.md) for scope and implementation boundaries. Root `preview.png` renders the actual NotchView using fictional media and theme stubs, not a desktop screenshot.

## Next

Live XPS acceptance first. Then persistent preferences and a bounded artwork-fetch path. Charging notices, notifications, file shelves and agent activity are deliberately outside this music-first preview.

MIT. Original implementation by Tom Ballard; built using the Build Omarchy Plugins v0.6.0 workflow. Existing Island/Notch projects were surveyed, but their code is not included.
