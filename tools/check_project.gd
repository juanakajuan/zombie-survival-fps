extends SceneTree
## Fails when project.godot is not in the editor's canonical form.
## Usage: godot --headless --path . -s res://tools/check_project.gd [-- --write]
## With --write it rewrites project.godot in that form (tools/canon_project.sh does this).

const CANON_PATH := "user://canon_project.godot"


func _init() -> void:
	var write := OS.get_cmdline_user_args().has("--write")
	var target := "res://project.godot"
	var out := ProjectSettings.globalize_path(target) if write else CANON_PATH
	if ProjectSettings.save_custom(out) != OK:
		printerr("check: cannot write %s" % out)
		quit(1)
		return
	if write:
		quit(0)
		return
	var canonical := FileAccess.get_file_as_string(CANON_PATH)
	var current := FileAccess.get_file_as_string(target)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CANON_PATH))
	if canonical != current:
		printerr("check: project.godot is not in the editor's canonical form. Run tools/canon_project.sh and commit the result.")
		quit(1)
		return
	quit(0)
