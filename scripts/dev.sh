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

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device="${1:-}"
pidfile="$(mktemp -t wayfare-flutter-pid)"
pids=()

# Kill a process and everything below it. `npm run dev` and `flutter run` both
# spawn children that outlive a plain kill and keep holding the port.
kill_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$child"; done
  kill "$pid" 2>/dev/null || true
}

cleanup() {
  for pid in "${pids[@]:-}"; do
    [ -n "$pid" ] && kill_tree "$pid"
  done
  rm -f "$pidfile"
}
trap cleanup EXIT INT TERM

# A server already on the port would leave the new one dead and the old one
# serving — confusing in exactly the way a stale server always is.
if lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "✗ something is already listening on :8080. Stop it first:"
  echo "    lsof -nP -iTCP:8080 -sTCP:LISTEN"
  exit 1
fi

# stdin from /dev/null, not the terminal. `tsx watch` reads stdin for its own
# keystrokes; a background job that reads the terminal gets SIGTTIN and stops
# dead — the server accepts connections and answers none of them, which looks
# exactly like a server that booted without its API keys.
echo "→ server on :8080"
(cd "$root/server" && exec npm run --silent dev < /dev/null) &
pids+=($!)

# Give Fastify a moment, so the app's first request does not land on nothing.
ready=""
for _ in $(seq 1 60); do
  if curl -sf -m 1 localhost:8080/health >/dev/null 2>&1; then ready=1; break; fi
  sleep 0.25
done
[ -n "$ready" ] || echo "! server did not answer /health — the app will show its features as off"

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
