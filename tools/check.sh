#!/usr/bin/env bash
# The gate. Imports the project, loads every script and scene (this enforces strict typing), then runs the tests.
# Usage: tools/check.sh [test filter]
set -euo pipefail
cd "$(dirname "$0")/.."

import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT
godot --headless --path . --import >"$import_log" 2>&1
if grep -E '^(ERROR|SCRIPT ERROR|USER ERROR)' "$import_log"; then
	echo "check: the import step logged errors" >&2
	exit 1
fi
godot --headless --path . -s res://tools/check_scripts.gd
timeout 300 godot --headless --path . -s res://tests/run_tests.gd -- --filter="${1:-}"
