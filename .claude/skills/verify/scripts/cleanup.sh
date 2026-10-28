#!/usr/bin/env bash
# Stops drive runs that this skill started (by the process group in each run's pid file) and removes the pid files.
# It never deletes evidence: PNG, JSON, logs, and steps stay in .smoke/verify/<run-id>/.
# Usage: .claude/skills/verify/scripts/cleanup.sh
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
for pidfile in "$repo"/.smoke/verify/*/pid; do
	[[ -f "$pidfile" ]] || continue
	pid="$(cat "$pidfile")"
	if kill -0 "$pid" 2>/dev/null; then
		kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid"
		echo "cleanup: stopped process group $pid"
	fi
	rm -f "$pidfile"
done
echo "cleanup: done. Evidence stays in $repo/.smoke/verify/"
