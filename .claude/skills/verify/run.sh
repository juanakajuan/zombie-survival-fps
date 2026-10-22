#!/usr/bin/env bash
# Usage: .claude/skills/verify/run.sh <scenario-file> [evidence-dir] [--seed <n>] [--invulnerable]
# VERIFY_TIMEOUT sets the limit for the game run in seconds (default 300).
set -euo pipefail
skill_dir="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$skill_dir/../../.." && pwd)"
scenario="$(realpath "$1")"
shift
evidence_arg=""
if [[ $# -gt 0 && $1 != --* ]]; then
	evidence_arg="$1"
	shift
fi
driver_options=("$@")
evidence="$(realpath -m "${evidence_arg:-$project/.verify/$(date +%Y%m%d-%H%M%S)-$(basename "$scenario" .txt)}")"
timeout_seconds="${VERIFY_TIMEOUT:-300}"
socket="zsfps-verify-$$"
# The private KWin and Godot get their own D-Bus session and KDE config. On the desktop session bus, the nested KWin
# fights the desktop KWin for org.kde.kglobalaccel and, when it exits, marks the desktop "kwin" shortcut component
# inactive: all Meta shortcuts stop until the next login.
private="$XDG_RUNTIME_DIR/$socket.d"
mkdir -p "$evidence" "$private/config" "$private/cache"
# cleanup.sh reads this file to stop only the instances that belong to its own worktree.
echo "$project" >"$private/project"

bus_pid=""
kwin_pid=""
godot_pid=""
cleanup() {
	[[ -n "$godot_pid" ]] && kill "$godot_pid" 2>/dev/null || true
	[[ -n "$kwin_pid" ]] && kill "$kwin_pid" 2>/dev/null || true
	wait $godot_pid $kwin_pid 2>/dev/null || true
	[[ -n "$bus_pid" ]] && kill "$bus_pid" 2>/dev/null || true
	wait 2>/dev/null || true
	rm -rf "$XDG_RUNTIME_DIR/$socket" "$XDG_RUNTIME_DIR/$socket.lock" "$private"
}
trap cleanup EXIT INT TERM

# No <servicedir>: nothing is auto-started on this bus, so no desktop service (portal, kglobalaccel) runs twice.
cat >"$private/bus.conf" <<BUS
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=$private/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
BUS
dbus-daemon --config-file="$private/bus.conf" --nofork --nopidfile >"$evidence/dbus.log" 2>&1 &
bus_pid=$!
for _ in $(seq 1 50); do
	[[ -S "$private/bus" ]] && break
	sleep 0.1
done
if [[ ! -S "$private/bus" ]]; then
	echo "FAIL: the private D-Bus did not start. See $evidence/dbus.log"
	exit 2
fi
export DBUS_SESSION_BUS_ADDRESS="unix:path=$private/bus"

XDG_CONFIG_HOME="$private/config" XDG_CACHE_HOME="$private/cache" kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --socket "$socket" --width 1600 --height 900 >"$evidence/kwin.log" 2>&1 &
kwin_pid=$!
for _ in $(seq 1 100); do
	[[ -S "$XDG_RUNTIME_DIR/$socket" ]] && break
	sleep 0.1
done
if [[ ! -S "$XDG_RUNTIME_DIR/$socket" ]]; then
	echo "FAIL: KWin did not open $socket. See $evidence/kwin.log"
	exit 2
fi

# A new class_name is missing from the class cache until an import, and the driver then fails to parse.
mkdir -p "$project/.godot"
if ! flock "$project/.godot/verify-import.lock" timeout 120 godot --headless --path "$project" --import >"$evidence/import.log" 2>&1; then
	echo "FAIL: the project import failed. See $evidence/import.log"
	exit 2
fi

status=0
WAYLAND_DISPLAY="$socket" timeout -k 5 "$timeout_seconds" godot --path "$project" --display-driver wayland --resolution 1600x900 --disable-vsync --max-fps 60 \
	--script res://.claude/skills/verify/driver.gd -- "$scenario" "$evidence" "${driver_options[@]}" >"$evidence/godot.log" 2>&1 &
godot_pid=$!
# Godot can hang on exit after a scene reload (seen after restart). The driver logs VERIFY DONE before quit,
# so a process alive 15 s after that line is stopped, and the run is judged from the log.
done_for=0
while kill -0 "$godot_pid" 2>/dev/null; do
	if grep -q '^VERIFY DONE' "$evidence/transcript.log" 2>/dev/null; then
		done_for=$((done_for + 1))
		if [[ $done_for -ge 15 ]]; then
			echo "NOTE: Godot did not exit 15 s after VERIFY DONE. Stopped it." | tee -a "$evidence/godot.log"
			kill "$godot_pid" 2>/dev/null || true
			break
		fi
	fi
	sleep 1
done
wait "$godot_pid" || status=$?
godot_pid=""
if grep -q '^NOTE: Godot did not exit' "$evidence/godot.log"; then
	grep -q '^VERIFY DONE failures=0' "$evidence/transcript.log" && status=0 || status=1
fi

grep -E '^(VERIFY|STEP|STATE|PASS|FAIL|REACHED|SHOT|NOTE)|SCRIPT ERROR|ERROR:' "$evidence/godot.log" || true
if [[ $status -eq 124 || $status -eq 137 ]] && ! grep -q '^VERIFY DONE' "$evidence/transcript.log" 2>/dev/null; then
	echo "RESULT: FAIL (timeout after $timeout_seconds s: the driver never printed VERIFY DONE; read $evidence/godot.log for the SCRIPT ERROR)"
	exit 1
fi
if [[ $status -ne 0 ]] || grep -qE 'SCRIPT ERROR|^ERROR:|^FAIL' "$evidence/godot.log"; then
	echo "RESULT: FAIL (exit $status). Evidence: $evidence"
	exit 1
fi
echo "RESULT: PASS. Evidence: $evidence"
