extends SceneTree
## Runs every test_ method of every tests/suites/*_test.gd on a new TestCase instance.
## Usage: godot --headless --path . --fixed-fps 60 -s tests/run.gd -- --skip-real-frames
##        godot --headless --path . -s tests/run.gd -- --real-frames
## A suite named *_real_frames_test.gd runs only with real frames, because its checks
## need rendered frames between physics ticks. Every other suite runs at the fixed rate.

const SUITES_DIR: String = "res://tests/suites"
const REAL_FRAMES_SUFFIX: String = "_real_frames_test.gd"

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	print("Physics engine setting: %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for path: String in suite_paths():
		var real_frames: bool = path.ends_with(REAL_FRAMES_SUFFIX)
		if real_frames and "--skip-real-frames" in args:
			continue
		if not real_frames and "--real-frames" in args:
			continue
		var script: GDScript = load(path)
		for method: String in test_methods(script):
			await run_test(script, path.get_file() + "::" + method, method)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 or checks == 0 else 0)


func suite_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(SUITES_DIR):
		if file.ends_with("_test.gd"):
			paths.append(SUITES_DIR.path_join(file))
	paths.sort()
	return paths


## The list also holds inherited methods, so only the test_ prefix selects a test.
func test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("test_") and not names.has(name):
			names.append(name)
	return names


func run_test(script: GDScript, id: String, method: String) -> void:
	var children_before: int = root.get_child_count()
	var orphans_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var test: TestCase = script.new()
	test.tree = self
	await test.call(method)
	test.release()
	checks += test.checks
	failures += test.failures
	if test.checks == 0:
		fail("%s made no assertion. Call ok, eq, near, or between, or delete the test." % id)
	var children_left: int = root.get_child_count() - children_before
	if children_left != 0:
		fail("%s left %d node(s) under root. End the test with await finish(level), or free the node it added." % [id, children_left])
	var orphans_left: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans_before
	if orphans_left > 0:
		fail("%s left %d orphan node(s) made with .new() and never freed. Pass each to own(), or call .free() on it." % [id, orphans_left])


func fail(message: String) -> void:
	failures += 1
	push_error("FAIL: " + message)
