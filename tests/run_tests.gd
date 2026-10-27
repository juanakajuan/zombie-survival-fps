extends SceneTree
## Runs every `test_*` method in res://tests/**/test_*.gd and exits with code 1 on any failure.
## A test fails when it records a failed assert or when the engine logs an error while it runs.
## Usage: godot --headless --path . -s res://tests/run_tests.gd [-- --filter=<substring of path:method>]

const TEST_DIR := "res://tests"


class ErrorLog extends Logger:
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var errors := _errors
		_errors = []
		_mutex.unlock()
		return errors


var _error_log := ErrorLog.new()


func _init() -> void:
	OS.add_logger(_error_log)
	_run.call_deferred()


func _run() -> void:
	var filter := _filter_arg()
	var passed := 0
	var failed := 0
	for path: String in _find_tests(TEST_DIR):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s: does not load" % path)
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			var id := "%s:%s" % [path.trim_prefix(TEST_DIR + "/"), method_name]
			var excluded := not filter.is_empty() and not id.contains(filter)
			if not method_name.begins_with("test_") or excluded:
				continue
			var problems := await _run_one(script, method_name)
			if problems.is_empty():
				passed += 1
				print("PASS ", id)
			else:
				failed += 1
				print("FAIL ", id)
				for problem: String in problems:
					print("  - ", problem)
	print("%d passed, %d failed" % [passed, failed])
	var nothing_matched := not filter.is_empty() and passed + failed == 0
	if nothing_matched:
		print("No test matches filter '%s'" % filter)
	quit(1 if failed > 0 or nothing_matched else 0)


func _run_one(script: GDScript, method_name: String) -> PackedStringArray:
	var instance: Object = script.new()
	var test := instance as TestCase
	if test == null:
		return PackedStringArray(["script does not extend TestCase"])
	_error_log.take()
	root.add_child(test)
	await test.call(method_name)
	var problems := test.failures + _error_log.take()
	test.queue_free()
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)
	await process_frame
	return problems


func _filter_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""


func _find_tests(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_find_tests(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.get_extension() == "gd":
			found.append(dir.path_join(file))
	return found
