#!/usr/bin/env bash
# Runs a Godot editor for this checkout off-screen in gamescope, so the godot-ai tools can work on a worktree.
# Its godot-ai plugin joins the server of the human's editor as a second session. Select it with session_activate and the worktree folder name.
# Usage: tools/editor.sh start | stop | status
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .smoke
pid_file=.smoke/editor.pid
log=.smoke/editor.log

running() {
	[[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

case "${1:-}" in
start)
	if running; then
		echo "editor: already running (pid $(cat "$pid_file"))"
		exit 0
	fi
	setsid gamescope --backend headless -W 1280 -H 720 -- \
		godot --path . -e --display-driver x11 --audio-driver Dummy >"$log" 2>&1 &
	echo "$!" >"$pid_file"
	for _ in $(seq 90); do
		if grep -q "MCP | authenticated with server" "$log"; then
			echo "editor: ready. Session name: $(basename "$PWD")"
			exit 0
		fi
		if ! running; then
			cat "$log" >&2
			echo "editor: the editor exited" >&2
			exit 1
		fi
		sleep 1
	done
	echo "editor: the godot-ai plugin did not connect in 90 s. Is the human's editor open? See $log" >&2
	exit 1
	;;
stop)
	if running; then
		kill -- "-$(cat "$pid_file")"
		echo "editor: stopped"
	fi
	rm -f "$pid_file"
	;;
status)
	if running; then echo "editor: running (pid $(cat "$pid_file"))"; else echo "editor: not running"; fi
	;;
*)
	echo "usage: tools/editor.sh start | stop | status" >&2
	exit 2
	;;
esac
