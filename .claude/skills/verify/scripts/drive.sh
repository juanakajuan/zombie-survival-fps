#!/usr/bin/env bash
# Plays a steps file against the real game, off-screen in gamescope, and writes evidence to .smoke/verify/<run-id>/.
# Usage: .claude/skills/verify/scripts/drive.sh <steps file> [run id]
# Exit 0: every step passed. Exit 1: a step or an expect failed, or the engine logged an error.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
steps="$(realpath "$1")"
run_id="${2:-$(basename "$steps" .steps)-$(date +%Y%m%d-%H%M%S)}"
out="$repo/.smoke/verify/$run_id"
if [[ -e "$out" ]]; then
	echo "drive: $out exists. Pick a new run id; evidence is never overwritten." >&2
	exit 2
fi
mkdir -p "$out"
cp "$steps" "$out/steps.txt"
log="$out/godot.log"

cd "$repo"
# No --fixed-fps: it stops zombie navigation. The run is real time, 60 physics frames a second.
# setsid gives the run its own process group, so cleanup.sh can stop exactly this run.
setsid timeout 300 gamescope --backend headless -W 1280 -H 720 -- \
	godot --path . --display-driver x11 \
	-s res://.claude/skills/verify/scripts/driver.gd -- --steps="$steps" --out="$out" >"$log" 2>&1 &
pid=$!
echo "$pid" >"$out/pid"
status=0
wait "$pid" || status=$?
rm -f "$out/pid"

grep -E '^driver: (\[|ok|FAIL|expected|done|ready|fight)|never became|not ready' "$log" || true
if grep -E '^(ERROR|SCRIPT ERROR|USER ERROR)' -A2 "$log"; then
	echo "drive: the engine logged errors (see $log)" >&2
	status=1
fi
# gamescope does not pass on the exit code of godot, so the driver's summary decides the result.
if [[ ! -f "$out/summary.txt" ]]; then
	echo "drive: the driver did not finish (see $log)" >&2
	status=1
elif ! grep -qx 'failures=0' "$out/summary.txt"; then
	echo "drive: $(cat "$out/summary.txt")" >&2
	status=1
fi
echo "drive: evidence in $out"
exit "$status"
