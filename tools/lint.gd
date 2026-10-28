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

	func _init(p_name: String, p_path: String, p_line: String, p_what: String, p_fix: String) -> void:
		name = p_name
		path_re = RegEx.create_from_string(p_path)
		line_re = RegEx.create_from_string(p_line)
		what = p_what
		fix = p_fix


const SKIP_DIRS: PackedStringArray = ["addons", ".godot", ".git", "worktrees"]
const ALLOW_MARK := "# lint-allow"
# This file quotes the lint-allow format in its own docs and messages.
const SELF_PATH := "tools/lint.gd"
const TEST_CASE_PATH := "res://tests/test_case.gd"
# The scan skips hidden folders, so files in them are listed here.
const HIDDEN_FILES: PackedStringArray = [".claude/skills/verify/scripts/driver.gd"]

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
			"^[^#]*\\bawait\\b",
			"await in a node script",
			"An await resumes on a freed node. Connect the signal: timer.timeout.connect(_f).",
		),
		Rule.new(
			"test_node_path",
			"^(tests/.*|\\.claude/skills/verify/scripts/driver)\\.gd$",
			"^[^#]*(get_node(_or_null)?\\(\\s*\"[^\"]*[/%]|\\$\"?%?\\w+/|\\$%|[A-Z]_PATH\\b|\"Head/|\"%[A-Z])",
			"node path into a scene",
			"Use a typed accessor on the feature class (player.camera, player.weapon, hud.readout()).",
		),
		Rule.new(
			"test_helper_copy",
			"^tests/(?!test_case\\.gd$).*\\.gd$",
			"^func\\s+_?(%s)\\s*\\(" % "|".join(_test_case_methods()),
			"copy of a TestCase helper",
			"Use TestCase.{1}().",
		),
	]
	var root := "res://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		root = args[0]
	_scan(root, root)
	for rel: String in HIDDEN_FILES:
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
	if rel == SELF_PATH:
		return
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i: int in lines.size():
		var line := lines[i]
		var allowed := _allowed_rule(rel, i + 1, line)
		for rule: Rule in _rules:
			if rule.path_re.search(rel) == null or rule.name == allowed:
				continue
			var found := rule.line_re.search(line)
			if found != null:
				_report(rel, i + 1, rule.what, rule.fix.replace("{1}", found.get_string(1)))


## The public methods of TestCase. Reads the names from the file, so a new helper is covered with no edit here.
func _test_case_methods() -> PackedStringArray:
	var names: PackedStringArray = []
	var func_re := RegEx.create_from_string("(?m)^func\\s+([a-z]\\w*)\\s*\\(")
	for found: RegExMatch in func_re.search_all(FileAccess.get_file_as_string(TEST_CASE_PATH)):
		names.append(found.get_string(1))
	return names


## Returns the rule that the line's lint-allow comment excuses, or "" when it has none or it is invalid.
func _allowed_rule(rel: String, line_number: int, line: String) -> String:
	if not line.contains(ALLOW_MARK):
		return ""
	var found := _allow_re.search(line)
	if found == null:
		_report(rel, line_number, "incomplete lint-allow", "Write: # lint-allow <rule>: <reason> (until YYYY-MM-DD, approved: <human>).")
		return ""
	var rule_name := found.get_string(1)
	var known := _rules.any(func(r: Rule) -> bool: return r.name == rule_name)
	if not known:
		_report(rel, line_number, "lint-allow names the unknown rule %s" % rule_name, "Use a rule name from tools/lint.gd.")
		return ""
	if found.get_string(3) < _today:
		_report(rel, line_number, "lint-allow for %s expired on %s" % [rule_name, found.get_string(3)], "Fix the code, or ask the human to renew the date.")
		return ""
	return rule_name


func _report(rel: String, line_number: int, what: String, fix: String) -> void:
	_hits += 1
	printerr("lint: %s:%d: %s. %s" % [rel, line_number, what, fix])
