#!/usr/bin/env bash
# Run explicitly: ./examples/build-with-perch.sh make
# Progress failures never change the build's exit status.
set -uo pipefail
if (( $# == 0 )); then
  printf 'Usage: %s COMMAND [ARGUMENT ...]\n' "$0" >&2
  exit 2
fi
reporter="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/perch-activity"
id="build.$$"
"$reporter" "$id" --title "Build running" --detail "$1" --ttl 3600 >/dev/null 2>&1 || true
"$@"
result=$?
if (( result == 0 )); then
  "$reporter" "$id" --state done --title "Build complete" --progress 1 >/dev/null 2>&1 || true
else
  "$reporter" "$id" --state error --title "Build failed" --detail "Exit code $result" --ttl 300 >/dev/null 2>&1 || true
fi
exit "$result"
