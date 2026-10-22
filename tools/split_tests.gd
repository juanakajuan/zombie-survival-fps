extends SceneTree
## Moves each test_ function of the old tests/test_runner.gd into tests/suites/<area>_test.gd.
## Usage: godot --headless --path . -s tools/split_tests.gd -- <test_runner.gd> <output dir>
## A helper that only one suite calls moves with that suite. A helper that several suites call
## must already be in tests/test_case.gd, or this script stops and names it.

const TEST_CASE_PATH: String = "res://tests/test_case.gd"

const RUNNER_FUNCTIONS: PackedStringArray = ["_initialize", "run", "tick_tests", "tests_that_need_frames_between_ticks", "check", "measure", "frames"]

const SUITES: Dictionary[String, Array] = {
	"movement_test.gd": ["test_ground_speed", "test_jump_height", "test_air_control", "test_coyote_time", "test_jump_buffer", "test_sprint_and_slide", "test_slide_jump_and_landing_slide", "test_stairs", "test_staircases", "test_ceiling", "test_mantle", "test_mantle_in_air", "test_mantle_headroom", "test_mantle_route", "test_slope_slide", "test_landed_signal", "test_camera_rig", "test_player_input", "test_player_health"],
	"camera_real_frames_test.gd": ["test_camera_on_mantle", "test_camera_on_stairs"],
	"rules_test.gd": ["test_rules", "test_round_director_start", "test_round_director_spawn_cap", "test_round_director_game_over", "test_points", "test_pick_spawn"],
	"weapons_test.gd": ["test_arsenal", "test_loadout", "test_wall_buy_offer", "test_mystery_box", "test_weapon", "test_melee", "test_weapon_switch", "test_shotgun"],
	"perks_test.gd": ["test_perks", "test_perk_effects"],
	"arena_test.gd": ["test_arena_navigation", "test_zombie", "test_zones"],
	"game_test.gd": ["test_game", "test_game_melee", "test_game_stations", "test_game_perks", "test_doors", "test_power", "test_secret"],
}

## Each entry rewrites a name the old runner had on itself to the name TestCase gives it.
const REWRITES: Dictionary[String, String] = {
	"\\bcheck\\(": "ok(",
	"\\bframes\\(": "ticks(",
	"\\bphysics_frame\\b": "tree.physics_frame",
	"\\bprocess_frame\\b": "tree.process_frame",
	"\\broot\\b": "tree.root",
	"\\bcurrent_scene\\b": "tree.current_scene",
	"\\bpaused\\b": "tree.paused",
}


class Block:
	var name: String
	var text: String
	var calls: PackedStringArray


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("ERROR: usage: split_tests.gd -- <test_runner.gd> <output dir>")
		quit(1)
		return
	var source: String = FileAccess.get_file_as_string(absolute(args[0]))
	if source.is_empty():
		printerr("ERROR: cannot read %s" % args[0])
		quit(1)
		return
	var problems: PackedStringArray = split(source, absolute(args[1]))
	for problem: String in problems:
		printerr("ERROR: " + problem)
	quit(1 if problems.size() > 0 else 0)


func absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") else path


func split(source: String, out_dir: String) -> PackedStringArray:
	var blocks: Array[Block] = parse_blocks(source)
	var by_name: Dictionary[String, Block] = {}
	for block: Block in blocks:
		by_name[block.name] = block
	var problems: PackedStringArray = []
	var suite_of_test: Dictionary[String, String] = {}
	for suite: String in SUITES:
		var tests: Array = SUITES[suite]
		for test: String in tests:
			suite_of_test[test] = suite
			if not by_name.has(test):
				problems.append("%s lists %s, which the source does not define" % [suite, test])
	var test_case_functions: PackedStringArray = function_names(FileAccess.get_file_as_string(TEST_CASE_PATH))
	var suites_of_helper: Dictionary[String, PackedStringArray] = {}
	for block: Block in blocks:
		if block.name.begins_with("test_"):
			if not suite_of_test.has(block.name):
				problems.append("%s is in no suite. Add it to SUITES." % block.name)
				continue
			for helper: String in helpers_reached(block, by_name, test_case_functions):
				if not suites_of_helper.has(helper):
					suites_of_helper[helper] = PackedStringArray()
				if not suites_of_helper[helper].has(suite_of_test[block.name]):
					suites_of_helper[helper].append(suite_of_test[block.name])
	var members: Dictionary[String, PackedStringArray] = {}
	for suite: String in SUITES:
		members[suite] = PackedStringArray()
	for block: Block in blocks:
		var owner: String = ""
		if block.name.begins_with("test_"):
			owner = suite_of_test.get(block.name, "")
		elif RUNNER_FUNCTIONS.has(block.name) or test_case_functions.has(block.name):
			continue
		elif not suites_of_helper.has(block.name):
			problems.append("%s is called by no test. Delete it." % block.name)
		elif suites_of_helper[block.name].size() > 1:
			problems.append("%s is called from %s. Move it to tests/test_case.gd." % [block.name, ", ".join(suites_of_helper[block.name])])
		else:
			owner = suites_of_helper[block.name][0]
		if not owner.is_empty():
			members[owner].append(block.name)
	if problems.size() > 0:
		return problems
	DirAccess.make_dir_recursive_absolute(out_dir)
	for suite: String in SUITES:
		var parts: PackedStringArray = ["extends TestCase\n"]
		for name: String in members[suite]:
			parts.append(rewrite(by_name[name].text))
		var file: FileAccess = FileAccess.open(out_dir.path_join(suite), FileAccess.WRITE)
		if file == null:
			problems.append("cannot write %s" % out_dir.path_join(suite))
			continue
		file.store_string("\n\n".join(parts))
		file.close()
		print("WROTE: %s (%d functions)" % [suite, members[suite].size()])
	return problems


## Each top-level func with the ## lines above it, in source order. The header before the first func is dropped.
func parse_blocks(source: String) -> Array[Block]:
	var blocks: Array[Block] = []
	var lines: PackedStringArray = source.split("\n")
	var pending: PackedStringArray = []
	var current: Block = null
	var call_pattern: RegEx = RegEx.create_from_string("\\b([a-z_][a-z0-9_]*)\\(")
	for line: String in lines:
		if line.begins_with("func "):
			current = Block.new()
			current.name = line.substr(5, line.find("(") - 5)
			pending.append(line)
			current.text = "\n".join(pending)
			pending.clear()
			blocks.append(current)
		elif line.begins_with("##"):
			pending.append(line)
		elif current != null and (line.begins_with("\t") or line.is_empty()):
			current.text += "\n" + line
		else:
			current = null
			pending.clear()
	for block: Block in blocks:
		block.text = block.text.strip_edges(false, true) + "\n"
		block.calls = PackedStringArray()
		for found: RegExMatch in call_pattern.search_all(block.text):
			var callee: String = found.get_string(1)
			if callee != block.name and not block.calls.has(callee):
				block.calls.append(callee)
	return blocks


## The helpers a test reaches, directly or through another helper that is not in TestCase.
func helpers_reached(test: Block, by_name: Dictionary[String, Block], test_case_functions: PackedStringArray) -> PackedStringArray:
	var reached: PackedStringArray = []
	var queue: PackedStringArray = test.calls.duplicate()
	while queue.size() > 0:
		var name: String = queue[0]
		queue.remove_at(0)
		if reached.has(name) or not by_name.has(name) or name.begins_with("test_") or RUNNER_FUNCTIONS.has(name) or test_case_functions.has(name):
			continue
		reached.append(name)
		queue.append_array(by_name[name].calls)
	return reached


func function_names(source: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for line: String in source.split("\n"):
		if line.begins_with("func "):
			names.append(line.substr(5, line.find("(") - 5))
	return names


func rewrite(text: String) -> String:
	var result: String = text
	for pattern: String in REWRITES:
		result = RegEx.create_from_string(pattern).sub(result, REWRITES[pattern], true)
	return result
