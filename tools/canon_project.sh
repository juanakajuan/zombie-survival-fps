#!/usr/bin/env bash
# Rewrites project.godot in the editor's canonical form, so tools/check_project.gd passes.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . -s res://tools/check_project.gd -- --write
