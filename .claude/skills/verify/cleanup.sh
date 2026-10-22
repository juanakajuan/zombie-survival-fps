#!/usr/bin/env bash
# Stops verify instances that a crashed or killed run.sh left behind, for this worktree only. It never touches the
# evidence in .verify/ or an instance that another worktree started.
# Each run.sh writes its project path to $XDG_RUNTIME_DIR/zsfps-verify-<pid>.d/project. A private KWin, D-Bus, or socket
# belongs to this worktree only when that file names this project. The Godot that runs driver.gd is matched by --path.
set -uo pipefail
project="$(cd "$(dirname "$0")/../../.." && pwd)"
runtime="${XDG_RUNTIME_DIR:?}"
mine=()
for marker in "$runtime"/zsfps-verify-*.d/project; do
	[[ -f "$marker" && "$(<"$marker")" == "$project" ]] || continue
	mine+=("$(basename "$(dirname "$marker")" .d)")
done
# pgrep -x matches the executable name only, so a shell whose command line names these patterns is never hit.
for pid in $(pgrep -x godot) $(pgrep -x kwin_wayland) $(pgrep -x dbus-daemon); do
	cmdline="$(tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null)"
	owned=0
	if [[ "$cmdline" == *"--path $project "* && "$cmdline" == *"verify/driver.gd -- "* ]]; then
		owned=1
	fi
	for instance in "${mine[@]}"; do
		if [[ "$cmdline" == *"--socket $instance "* || "$cmdline" == *"/$instance.d/bus.conf"* ]]; then
			owned=1
		fi
	done
	if [[ $owned -eq 1 ]]; then
		echo "stop $pid: ${cmdline:0:120}"
		kill "$pid" 2>/dev/null
	fi
done
sleep 1
for instance in "${mine[@]}"; do
	rm -rf "${runtime:?}/$instance" "${runtime:?}/$instance.lock" "${runtime:?}/$instance.d"
done
echo "cleanup done. Evidence kept in $project/.verify"
