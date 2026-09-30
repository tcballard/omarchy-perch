# Rust backend builds

Perch keeps its native QML interface. Runtime helpers, agent adapters, request
bridges, SSH relay and notification persistence run in `perch-backend`.
Python and Node are development test tools only.

## Build a source checkout

Use Rust/Cargo 1.88 or newer on Linux:

```bash
./scripts/build-backend
./tests/run
```

The build uses `backend/Cargo.lock` and installs the release executable at
`bin/perch-backend`. Cargo intermediates live outside the plugin tree in
`$XDG_CACHE_HOME/omarchy-perch-build/target` (or `~/.cache/omarchy-perch-build/target`),
so host validation does not walk build products. QML and helper scripts never build or fetch an executable
when they start. A missing build produces an actionable error. Rebuild after
switching branches or updating a source checkout, before enabling Perch.

## Package a preview

```bash
./scripts/package-preview
```

This produces a Linux archive and SHA-256 checksum in `dist/`, containing both
source and the compiled backend. The filename includes version, commit and
architecture. The GitHub test workflow publishes the same x86_64 archive as a
review artifact; it does not publish a release or change tags.

Testers using an archive need neither Rust nor Python. Verify its checksum,
disable an existing Perch installation, preserve that installation and its
local edits, and extract the archive into the normal plugin directory:

```bash
sha256sum -c perch-*.tar.gz.sha256
mkdir -p "$HOME/.config/omarchy/plugins/io.github.tcballard.perch"
tar -xzf perch-*.tar.gz --strip-components=1 \
  -C "$HOME/.config/omarchy/plugins/io.github.tcballard.perch"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.tcballard.perch"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.tcballard.perch
omarchy restart shell
```

Extract into a fresh directory; do not overlay a modified installation. State
stays in the existing private XDG state directory. Native Omarchy/Quickshell
modules and each feature's external CLI still need to be present. HTTP weather,
optional remote artwork and explicit downloads use curl. The packaged binary
uses the build host's Linux ABI; live Omarchy acceptance remains necessary.

## Upgrade existing hooks

Reapply enabled integrations from Setup, or use the corresponding setup script
with `--apply`. Perch recognizes its exact legacy Python hook commands and
migrates them to executable Rust adapters. It preserves unrelated hooks,
notifiers, status lines and managed restrictions, and writes dated backups.
The copied backend has an ownership checksum; setup refuses a changed or
unrelated binary rather than overwriting it. Restart clients and review hooks
where the client requires trust.

For git-managed installs, the host updater retains its clean-tree/default-branch
checks. Source updates require Cargo and finish a locked release build before
replacing the executable. Copied hooks and companions still require explicit
Setup updates. Archive installs use the next reviewed archive.

## Verification

Rust tests check parser bounds, recurrence/time zones, hook ownership, private
storage, command deadlines, status privacy and decision rules. Python tests
exercise the compiled executable and installed adapters. CI requires real Unix
socket and HTTP checks, including approval delivery acknowledgment, relay
ownership, cancellation cleanup and truncated downloads. Locally, those checks
are explicitly reported unavailable if a sandbox denies socket creation.
Production QML and JavaScript policy tests remain part of `tests/run`.
