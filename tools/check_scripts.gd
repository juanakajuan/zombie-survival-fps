extends SceneTree
## Loads every script, scene, and resource under res:// and exits with code 1 if any fails.
## Strict-typing warnings are errors in project.godot, so this also enforces static typing.
## Run it through tools/check.sh, which imports the project first.

const SKIP_DIRS: PackedStringArray = ["res://addons"]
const HiddenScripts := preload("res://tools/hidden_scripts.gd")


func _init() -> void:
	var failed: PackedStringArray = []
	var paths := _find_files("res://")
	for rel: String in HiddenScripts.FILES:
		paths.append("res://".path_join(rel))
	for path: String in paths:
		if not _loads(path):
			failed.append(path)
	for path: String in failed:
		printerr("FAILED: ", path)
	print("check_scripts: %d files, %d failed" % [paths.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)


func _loads(path: String) -> bool:
	var resource := load(path)
	if resource is GDScript:
		return (resource as GDScript).can_instantiate()
	if resource is PackedScene:
		return (resource as PackedScene).can_instantiate()
	return resource != null


func _find_files(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for sub: String in DirAccess.get_directories_at(dir):
		var sub_path := dir.path_join(sub)
		if sub_path not in SKIP_DIRS:
			found.append_array(_find_files(sub_path))
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			found.append(dir.path_join(file))
	return found
