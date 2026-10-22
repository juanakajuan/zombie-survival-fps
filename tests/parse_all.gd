extends SceneTree


func _initialize() -> void:
	var paths: PackedStringArray = tracked_scripts()
	if paths.is_empty():
		printerr("ERROR: git ls-files listed no .gd files")
		quit(1)
		return
	var self_script: Script = get_script()
	var self_path: String = self_script.resource_path
	var broken: int = 0
	for path: String in paths:
		if "res://" + path == self_path:
			continue
		var loaded: Resource = ResourceLoader.load("res://" + path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
		var script: GDScript = loaded as GDScript
		if script == null or not script.can_instantiate():
			broken += 1
			printerr("ERROR: cannot load %s" % path)
	print("PARSED: %d scripts, %d broken" % [paths.size(), broken])
	quit(1 if broken > 0 else 0)


func tracked_scripts() -> PackedStringArray:
	var output: Array = []
	var status: int = OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "ls-files", "--cached", "--others", "--exclude-standard", "*.gd"], output)
	if status != 0:
		return PackedStringArray()
	var text: String = str(output[0])
	return PackedStringArray(text.split("\n", false))
