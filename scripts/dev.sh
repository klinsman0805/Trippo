#!/usr/bin/env bash
#
# One command for the whole loop: the API server, and the app reloading itself
# whenever a Dart file changes.
#
#   ./scripts/dev.sh            # first attached device
#   ./scripts/dev.sh <deviceId> # a specific one — `flutter devices` lists them
#
# The server already reloads itself (tsx watch). The app does not: `flutter
# run` reloads when you press `r` in its terminal, which means every change
# costs a context switch. Flutter also reloads on SIGUSR1 when given a pid
# file, so a file watcher can press that key for you.
set -euo pipefail
# Job control, so each background child leads its own process group and the
# cleanup below takes its grandchildren with it.
set -m

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device="${1:-}"
pidfile="$(mktemp -t wayfare-flutter-pid)"
pids=()

cleanup() {
  # Kill the whole process group of each child: `npm run dev` and `flutter run`
  # both spawn their own children, which outlive a plain kill and hold the port.
  for pid in "${pids[@]:-}"; do
    [ -n "$pid" ] && kill -- "-$pid" 2>/dev/null || true
  done
  rm -f "$pidfile"
}
trap cleanup EXIT INT TERM

echo "→ server on :8080"
(cd "$root/server" && exec npm run --silent dev) &
pids+=($!)

# Give Fastify a moment, so the app's first request does not land on nothing.
for _ in $(seq 1 40); do
  curl -sf -m 1 localhost:8080/health >/dev/null 2>&1 && break
  sleep 0.25
done

echo "→ watching app/lib for changes"
(
  cd "$root/app"
  # Hash the mtimes rather than diffing files: cheap, and it catches adds and
  # deletes as well as edits. A second of latency is not worth a dependency.
  last=""
  while true; do
    now="$(find lib test -name '*.dart' -exec stat -f '%m %N' {} + 2>/dev/null | sort | shasum)"
    if [ -n "$last" ] && [ "$now" != "$last" ] && [ -s "$pidfile" ]; then
      kill -USR1 "$(cat "$pidfile")" 2>/dev/null && echo "↻ hot reload"
    fi
    last="$now"
    sleep 1
  done
) &
pids+=($!)

echo "→ flutter run — press R to restart, q to quit (r is automatic)"
cd "$root/app"
if [ -n "$device" ]; then
  flutter run --pid-file "$pidfile" -d "$device"
else
  flutter run --pid-file "$pidfile"
fi
