extends SceneTree
## Line rules for the project scripts. Run it through tools/check.sh.
## Usage: godot --headless --path . -s res://tools/lint.gd [-- <dir>]
## The optional <dir> replaces res:// as the scan root (to prove a rule on an old checkout).
## Output: `lint: <file>:<line>: <what>. <fix>`. Exit code 1 on any hit.
## An exception goes on the offending line:
## `# lint-allow <rule>: <reason> (until YYYY-MM-DD, approved: <human>)`

class Rule:
	var name: String
	var path_re: RegEx
	var line_re: RegEx
	var what: String
	var fix: String
	## When false, the rule sees each string literal as "", so text in a string cannot match.
	var reads_strings: bool

	func _init(p_name: String, p_path: String, p_line: String, p_what: String, p_fix: String, p_reads_strings: bool = false) -> void:
		name = p_name
		path_re = RegEx.create_from_string(p_path)
		line_re = RegEx.create_from_string(p_line)
		what = p_what
		fix = p_fix
		reads_strings = p_reads_strings


const SKIP_DIRS: PackedStringArray = ["addons"]
const ALLOW_MARK := "# lint-allow"
const TEST_CASE_PATH := "res://tests/test_case.gd"
const HiddenScripts := preload("res://tools/hidden_scripts.gd")

var _rules: Array[Rule] = []
var _allow_re := RegEx.create_from_string(
	"#\\s*lint-allow\\s+(\\w+):\\s*(\\S.*?)\\s*\\(until (\\d{4}-\\d{2}-\\d{2}), approved: (\\S[^)]*)\\)"
)
var _today: String = Time.get_date_string_from_system()
var _hits: int = 0


func _init() -> void:
	_rules = [
		Rule.new(
			"await_in_node",
			"^(?!tests/|tools/|debug/|\\.claude/).*\\.gd$",
			"\\bawait\\b",
			"await in a node script",
			"An await resumes on a freed node. Connect the signal: timer.timeout.connect(_f).",
		),
		Rule.new(
			"test_node_path",
			"^(tests/.*|\\.claude/skills/verify/scripts/driver)\\.gd$",
			"(get_node(_or_null)?\\(\\s*\"[^\"]*[/%]|\\$\"?%?\\w+/|\\$%|[A-Z]_PATH\\b|\"Head/|\"%[A-Z])",
			"node path into a scene",
			"Use a typed accessor on the feature class (player.camera, player.weapon, hud.readout()).",
			true,
		),
		Rule.new(
			"test_helper_copy",
			"^tests/(?!test_case\\.gd$).*\\.gd$",
			"^func\\s+_?(%s)\\s*\\(" % "|".join(_test_case_methods()),
			"copy of a TestCase helper",
			"Use TestCase.{1}().",
		),
		Rule.new(
			"group_literal",
			"^(?!tests/).*\\.gd$",
			"\\b(add_to_group|remove_from_group|is_in_group|get_first_node_in_group|get_nodes_in_group|call_group)\\(\\s*&?[\"']|\\bcall_group_flags\\(\\s*[^,]+,\\s*&?[\"']",
			"group name as a string literal",
			"Use the owner's constant, for example Player.GROUP.",
			true,
		),
		Rule.new(
			"mouse_mode_owner",
			"^(?!player/player\\.gd$|tests/|debug/|\\.claude/).*\\.gd$",
			"(Input\\.mouse_mode|\\btrigger_enabled)\\s*=[^=]|\\bInput\\.set_mouse_mode\\(",
			"mouse mode or trigger written outside Player",
			"Only Player writes the mouse mode and the trigger. Ask the player (Player.died, a Player method) instead.",
		),
		Rule.new(
			"ancestor_walk",
			"^(?!tests/|tools/|debug/|\\.claude/).*\\.gd$",
			"\\b(\\w+)\\s*=\\s*\\1\\.get_parent\\(\\)",
			"loop up the tree to find an owner",
			"Have the owner set a typed reference in code, as Player sets weapon.wielder.",
		),
		Rule.new(
			"magic_const",
			"^(?!tests/|tools/|debug/|\\.claude/).*\\.gd$",
			"^\\s*const\\s+\\w+\\s*(:\\s*\\w+)?\\s*:?=\\s*(-?[\\d.]|Color\\()",
			"numeric or Color const in a gameplay script",
			"Make it @export (with @export_range) or put it in a .tres.",
		),
	]
	var root := "res://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		root = args[0]
	_scan(root, root)
	for rel: String in HiddenScripts.FILES:
		if FileAccess.file_exists(root.path_join(rel)):
			_lint_file(rel, root.path_join(rel))
	print("lint: %d hits" % _hits)
	quit(1 if _hits > 0 else 0)


func _scan(root: String, dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if sub not in SKIP_DIRS:
			_scan(root, dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			_lint_file(dir.path_join(file).substr(root.length()).lstrip("/"), dir.path_join(file))


func _lint_file(rel: String, path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i: int in lines.size():
		var line := lines[i]
		var allowed := _allowed_rule(rel, i + 1, line)
		var code := _without_comment(line, true)
		var bare := _without_comment(line, false)
		for rule: Rule in _rules:
			if rule.path_re.search(rel) == null or rule.name == allowed:
				continue
			var found := rule.line_re.search(code if rule.reads_strings else bare)
			if found != null:
				_report(rel, i + 1, rule.what, rule.fix.replace("{1}", found.get_string(1)))


## Without `keep_strings`, each string literal becomes "".
## A `#` in a string does not start a comment.
func _without_comment(line: String, keep_strings: bool) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote.is_empty():
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
			out += c
		elif c == "\\":
			if keep_strings:
				out += line.substr(i, 2)
			i += 1
		elif c == quote:
			quote = ""
			out += c
		elif keep_strings:
			out += c
		i += 1
	return out


func _test_case_methods() -> PackedStringArray:
	var names: PackedStringArray = []
	var func_re := RegEx.create_from_string("(?m)^func\\s+([a-z]\\w*)\\s*\\(")
	for found: RegExMatch in func_re.search_all(FileAccess.get_file_as_string(TEST_CASE_PATH)):
		names.append(found.get_string(1))
	return names


func _allowed_rule(rel: String, line_number: int, line: String) -> String:
	var comment := line.substr(_without_comment(line, true).length())
	if not comment.begins_with(ALLOW_MARK):
		return ""
	var found := _allow_re.search(comment)
	if found == null:
		_report(rel, line_number, "incomplete lint-allow", "Write: # lint-allow <rule>: <reason> (until YYYY-MM-DD, approved: <human>).")
		return ""
	var rule_name := found.get_string(1)
	var known := _rules.any(func(r: Rule) -> bool: return r.name == rule_name)
	if not known:
		_report(rel, line_number, "lint-allow names the unknown rule %s" % rule_name, "Use a rule name from tools/lint.gd.")
		return ""
	if not _is_date(found.get_string(3)):
		_report(rel, line_number, "lint-allow date %s is not a valid date" % found.get_string(3), "Write the date as YYYY-MM-DD.")
		return ""
	if found.get_string(3) < _today:
		_report(rel, line_number, "lint-allow for %s expired on %s" % [rule_name, found.get_string(3)], "Fix the code, or ask the human to renew the date.")
		return ""
	return rule_name


## True for a real calendar date in YYYY-MM-DD form. The regex already checks the form.
func _is_date(date: String) -> bool:
	var parts := date.split("-")
	var year := parts[0].to_int()
	var month := parts[1].to_int()
	var day := parts[2].to_int()
	if month < 1 or month > 12:
		return false
	var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
	var days_in_month: PackedInt32Array = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= days_in_month[month - 1]


func _report(rel: String, line_number: int, what: String, fix: String) -> void:
	_hits += 1
	printerr("lint: %s:%d: %s. %s" % [rel, line_number, what, fix])
