#!/usr/bin/env bash
# The gate. Imports the project, lints the scripts, checks project.godot, loads every script and scene (this enforces strict typing), then runs the tests.
# Usage: tools/check.sh [test filter]
set -euo pipefail
cd "$(dirname "$0")/.."

test_budget_seconds=15

import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT

phase_start=$SECONDS
godot --headless --path . --import >"$import_log" 2>&1
if grep -E '^(ERROR|SCRIPT ERROR|USER ERROR)' "$import_log"; then
	echo "check: the import step logged errors" >&2
	exit 1
fi
echo "check: import took $((SECONDS - phase_start)) s"

phase_start=$SECONDS
godot --headless --path . -s res://tools/lint.gd
godot --headless --path . -s res://tools/check_project.gd
echo "check: lint and project check took $((SECONDS - phase_start)) s"

phase_start=$SECONDS
godot --headless --path . -s res://tools/check_scripts.gd
echo "check: scripts took $((SECONDS - phase_start)) s"

phase_start=$SECONDS
timeout 300 godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- --filter="${1:-}"
test_seconds=$((SECONDS - phase_start))
echo "check: tests took $test_seconds s"
if ((test_seconds > test_budget_seconds)); then
	echo "check: tests took $test_seconds s, budget is $test_budget_seconds s. A test waits for real time, or --fixed-fps 60 was removed from tools/check.sh." >&2
	exit 1
fi
