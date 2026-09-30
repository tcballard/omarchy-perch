# Test the Perch preview

**Rust migration preview · unreleased.** The published `0.0.1` tag is unchanged.
Use [BUILDING.md](BUILDING.md) for a compiled review archive or source build.

Perch puts music, files, timers, meetings and your chosen plugins at the edge of
Omarchy. This preview also includes optional coding-agent status and selected
approval/question integrations. We want feedback on everyday usability,
responsiveness and reliability before a stable release.

## Compatibility and evidence

Requires the plugin-capable **Omarchy Quattro shell**, including its scoped
`updateEntryInline` settings API and the shell's native Quickshell
modules. This is not intended for older non-plugin Omarchy installations.
Integration contracts were inspected against Omarchy source
`b421b1b479ee9ea0863792282eee4ffeb50923dc`; that is a source reference, not a
claim of a successful desktop test on that revision.

Portable tests and production QML fixtures are automated in CI. Hardware,
compositor, install/update/removal and real agent round trips still need live
testing. The screenshots are labelled fixture renders, not proof of a complete
desktop acceptance pass. Check the candidate PR's current CI before installing.

## Install the review candidate

The normal add command clones the default branch. Until this stack is merged,
select the Rust review branch and build its backend **before enabling** it. Do not use `--enable` on the
first command below. A published preview will instead have an immutable tag.

Fresh install, one command at a time:

```bash
omarchy plugin add https://github.com/tcballard/omarchy-perch.git
```

```bash
git -C "$HOME/.config/omarchy/plugins/io.github.tcballard.perch" fetch origin rust/native-runtime
```

```bash
git -C "$HOME/.config/omarchy/plugins/io.github.tcballard.perch" switch --detach origin/rust/native-runtime
```

```bash
"$HOME/.config/omarchy/plugins/io.github.tcballard.perch/scripts/build-backend"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.tcballard.perch"
```

```bash
omarchy plugin enable io.github.tcballard.perch
```

```bash
omarchy restart shell
```

```bash
omarchy-shell shell summon io.github.tcballard.perch
```

For an existing installation, first record `git rev-parse HEAD` and check
`git status --short` in that plugin directory. Keep any local edits; do not reset
them. Disable Perch with `omarchy plugin disable io.github.tcballard.perch`, then
follow the fetch, switch, validate, enable and restart steps above. Git must show
a clean working tree before switching the candidate.

The branch can receive fixes: repeat fetch/switch/validate/restart deliberately
to update, then open **Setup & health** and update any enabled copied integrations
it marks outdated. Record the new commit with each report. Host automatic
updates intentionally do not update this detached preview checkout.

## First ten minutes

1. Open Perch and Settings. Switch between **Notch** and **Plugin Perch**; choose
   an edge and the Omarchy theme option. Open/close by pointer, then summon by
   command and use the keyboard. Check Escape, outside clicks and dropdowns.
2. Play music, try pause/seek and change player if you have more than one.
3. Start a one-minute timer. Close Perch and confirm completion appears. Turn
   Quiet mode on and confirm automatic interruptions stop.
4. Add a disposable file reference to the shelf, preview/open it, then remove
   the reference. Confirm the original file remains.
5. Copy some harmless text, open Clipboard, select it and paste into another
   app after closing Perch.
6. Pin an enabled plugin. Open its panel. Native cards require the provider's
   Perch integration; the standard fallback is expected for other plugins.
7. Restart the shell. Confirm preferences, pins and timer state survive.
8. If available, try your second monitor, display scaling and a fullscreen app.

Report which steps passed, failed or were not tested. A short screen recording
of an awkward interaction is especially useful; hide personal content first.

## Optional integrations: test one at a time

**Setup & health** shows missing dependencies and explicit enable/disable actions.
Begin with the built-in tools. Enable only an integration you intend to test.

- Agent status: select your installed client, start a new session, check working,
  attention and completion states, then try session return. Record client and
  terminal versions. Codex hooks require review/trust in Codex itself.
- Approvals: separate opt-in bridges support Claude, Codex and OpenCode v1;
  Claude also supports question answers. Test with a harmless command. Expiry,
  unavailable clients and rejected delivery leave decisions in the agent.
- Notifications and system feedback replace Omarchy's corresponding stock owner
  while enabled. Test enable, receipt, disable and restoration individually.
- Weather needs explicit coordinates and sends them to Open-Meteo. Remote music
  artwork is separately opt-in. Calendar input is a local ICS file.
- SSH status and Codex existing-server observation are advanced opt-ins. They do
  not provide remote approvals or app-server decision responses.

## Preview limitations

- This is not full Open Island parity. Agent cards primarily show status, not
  full conversations, subagent/task trees or follow-up reply composition.
- Up to 32 live activity rows. At capacity, old idle/completed rows are replaced
  first. New attention may replace ordinary running work; existing attention
  and unresolved request rows are protected. If all slots are protected, a new
  request falls back to its agent. Up to eight simultaneous request bridges;
  recovery/discovery each retain their existing eight-session bounds.
- OpenCode questions remain in OpenCode; v2 is unsupported. Request bridges
  expire after 120 seconds. Support for 13 status clients does not mean identical
  interactive features across all 13.
- Window return depends on a verified target. Zellij selects a pane without
  focusing its desktop window. Ambiguous targets fail rather than guess.
- Native plugin cards require provider support. RSS has a separate pending
  integration PR; arbitrary plugin UIs are not embedded.
- Clipboard deletion belongs to the existing Omarchy clipboard UI. Calendar
  account sync is external, recurrence support is bounded, and lyrics use local
  files. Hardware/player capabilities vary.
- Mobile/watch companions, richer session preferences and automatic agent
  discovery beyond the documented metadata reader are not included.

See the [README](README.md) for dependencies, network access, stored data and
the exact per-integration boundaries. The preview does not need any account
login of its own and does not send telemetry.

## Feedback

Run this locally for a small support report, then review it before attaching:

```bash
"$HOME/.config/omarchy/plugins/io.github.tcballard.perch/scripts/perch-support"
```

It reports Perch version/revision, whether the checkout has edits, Linux/backend
versions and optional-command availability. It does not read agent transcripts,
shell configuration, notification/clipboard history, credentials or logs, and
does not upload anything. Add your Omarchy version, monitor/scale, relevant
client versions and optional integrations manually.

[Report a bug or usability issue](https://github.com/tcballard/omarchy-perch/issues/new/choose).
Include expected behaviour, actual behaviour, minimal steps, frequency and
whether the issue disappears with Perch disabled. Do not post raw configs,
transcripts, tokens or unreviewed logs. Missing preview features listed above
are known limitations; feedback about their importance is welcome.

## Disable, remove or go back

Before disabling or removing a configured installation, open Setup and choose
**Prepare Perch for removal**. Wait for successful completion: this removes
owned hooks/companions and restores stock owners. If it fails, resolve that
reported step before deleting Perch. It retains user data and original files.

To remove:

```bash
omarchy plugin remove io.github.tcballard.perch
```

```bash
omarchy restart shell
```

To return to your previous version instead, prepare removal first, disable
Perch, switch the clean checkout to the commit you recorded, validate, enable
and restart. Re-enable integrations from that version's Setup. Do not leave
newer copied hooks/companions installed against an older core.

Perch's own retained state defaults to `~/.local/state/omarchy-perch` and cached
artwork to `~/.cache/omarchy-perch` (or the corresponding XDG locations).
Removal deliberately leaves these intact. Delete them only if you want to
erase saved references/history; shelf originals are never deleted by Perch.
