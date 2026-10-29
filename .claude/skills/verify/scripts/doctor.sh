#!/usr/bin/env bash
# Read-only check: is this checkout ready to drive? Prints one line per check and exits 1 if any fails.
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "godot is on PATH" "command -v godot"
check "godot is 4.7.x ($(godot --version 2>/dev/null))" "godot --version | grep -q '^4\.7\.'"
check "gamescope is on PATH" "command -v gamescope"
check "project is imported (.godot/imported exists)" "test -d '$repo/.godot/imported'"
check "class cache has Player, Hud, GameOver" "grep -q '\"Player\"' '$repo/.godot/global_script_class_cache.cfg' && grep -q '\"GameOver\"' '$repo/.godot/global_script_class_cache.cfg'"
for pidfile in "$repo"/.smoke/verify/*/pid; do
	[[ -f "$pidfile" ]] || continue
	if kill -0 "$(cat "$pidfile")" 2>/dev/null; then
		echo "WARN a drive is still running: $pidfile (cleanup.sh stops it)"
	else
		echo "WARN stale pid file: $pidfile (cleanup.sh removes it)"
	fi
done
exit "$fail"
