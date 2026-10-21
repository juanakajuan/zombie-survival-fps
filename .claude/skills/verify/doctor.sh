#!/usr/bin/env bash
# Read-only check: can this machine drive the game now? Prints OK or PROBLEM per line. Exit 1 on any PROBLEM.
skill_dir="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$skill_dir/../../.." && pwd)"
problems=0
ok() { echo "OK: $1"; }
bad() { echo "PROBLEM: $1"; problems=$((problems + 1)); }

version="$(godot --version 2>/dev/null)"
[[ "$version" == 4.7.* ]] && ok "godot $version" || bad "godot 4.7 not on PATH (got '${version:-nothing}')"
command -v dbus-daemon >/dev/null && ok "dbus-daemon found (private D-Bus for the private display)" || bad "dbus-daemon missing: run.sh needs it to keep KWin off the desktop bus"
command -v kwin_wayland >/dev/null && ok "kwin_wayland found (private headless display)" || bad "kwin_wayland missing: run.sh needs it for the private display"
[[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]] && ok "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" || bad "XDG_RUNTIME_DIR not set"
cache="$project/.godot/global_script_class_cache.cfg"
if [[ ! -f "$cache" ]]; then
	bad "project not imported: run 'godot --headless --path . --editor --quit'"
else
	# A class_name added after the last import is missing from the cache, and every scene that uses it fails to parse.
	missing="$(grep -rhoP '^class_name \K\w+' "$project/game" | while read -r name; do grep -q "&\"$name\"" "$cache" || echo "$name"; done | tr '\n' ' ')"
	[[ -z "$missing" ]] && ok "project imported (class cache has every class_name)" || bad "class cache is stale, missing: ${missing}run 'godot --headless --path . --editor --quit'"
fi
[[ -e "$project/override.cfg" ]] && bad "override.cfg exists: it changes engine settings (tests/run_checks.sh may have left it)" || ok "no override.cfg"
stray="$( { pgrep -ax godot; pgrep -ax kwin_wayland; pgrep -ax dbus-daemon; } | grep -E 'verify/driver\.gd -- |--socket zsfps-verify-|/zsfps-verify-[0-9]+\.d/bus\.conf' || true)"
[[ -z "$stray" ]] && ok "no verify instances running" || bad "verify instances still running (cleanup.sh stops them):
$stray"
[[ -d "$project/.verify" ]] && ok "evidence dir $project/.verify has $(find "$project/.verify" -mindepth 1 -maxdepth 1 -type d | wc -l) runs" || ok "no evidence yet ($project/.verify)"
exit $((problems > 0))
