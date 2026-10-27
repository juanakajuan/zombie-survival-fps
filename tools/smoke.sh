#!/usr/bin/env bash
# Runs the game off-screen for N frames and saves a screenshot. Fails if the engine logs an error.
# gamescope's headless backend renders on the GPU without a window, so nothing opens on the desktop.
# Usage: tools/smoke.sh [scene res:// path] [frames] [out png]
set -euo pipefail
cd "$(dirname "$0")/.."

scene="${1:-}"
frames="${2:-90}"
out="$(realpath -m "${3:-.smoke/smoke.png}")"
mkdir -p "$(dirname "$out")"
rm -f "$out"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! timeout 120 gamescope --backend headless -W 1280 -H 720 -- \
	godot --path . --display-driver x11 ${scene:+"$scene"} -- --smoke-out="$out" --smoke-frames="$frames" >"$log" 2>&1; then
	cat "$log" >&2
	echo "smoke: the game exited with an error" >&2
	exit 1
fi
if grep -E '^(ERROR|SCRIPT ERROR|USER ERROR)' -A2 "$log"; then
	echo "smoke: the engine logged errors" >&2
	exit 1
fi
if [[ ! -f "$out" ]]; then
	echo "smoke: no screenshot at $out" >&2
	exit 1
fi
echo "smoke: screenshot at $out"
