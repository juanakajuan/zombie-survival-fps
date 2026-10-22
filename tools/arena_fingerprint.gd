extends SceneTree
## Dumps every node of an arena after _ready and the navigation bake, so two builds can be diffed.
## Usage: godot --headless --path . -s tools/arena_fingerprint.gd -- <scene|code> <out-file>

const SKIP: PackedStringArray = ["scene_file_path", "unique_id"]

## The first place each embedded resource was seen, to list sharing apart from values.
var _first_use: Dictionary[Resource, String] = {}
var _out: PackedStringArray = []
var _shared: PackedStringArray = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var arena: Node3D
	if args[0] == "scene":
		var scene: PackedScene = load("res://game/level/arena.tscn")
		arena = scene.instantiate()
	else:
		arena = Arena.create()
	root.add_child(arena)
	await process_frame
	await physics_frame
	await process_frame
	_node(arena, arena)
	_out.append("== embedded resources used by more than one property ==")
	_out.append_array(_shared)
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string("\n".join(_out) + "\n")
	file.close()
	print("nodes and properties: %d lines" % _out.size())
	quit(0)


func _node(node: Node, arena: Node) -> void:
	var path: String = _clean(str(arena.get_path_to(node)))
	var script: Script = node.get_script()
	var owner_text: String = "none" if node.owner == null else _clean(str(arena.get_path_to(node.owner)))
	_out.append("%s | %s | script=%s | owner=%s" % [path, node.get_class(), script.resource_path if script != null else "", owner_text])
	if node is Node3D:
		_out.append("%s  global_transform = %s" % [path, var_to_str((node as Node3D).global_transform)])
	_props(path, node, 1)
	for child: Node in node.get_children():
		_node(child, arena)


func _props(prefix: String, object: Object, depth: int) -> void:
	for property: Dictionary in object.get_property_list():
		var usage: int = property["usage"]
		var key: String = property["name"]
		if usage & PROPERTY_USAGE_STORAGE == 0 or SKIP.has(key) or key == "script":
			continue
		var value: Variant = object.get(key)
		var indent: String = "  ".repeat(depth)
		if value is Resource:
			var resource: Resource = value
			var embedded: bool = resource.resource_path == "" or resource.resource_path.contains("::")
			_out.append("%s%s%s = %s %s" % [prefix, indent, key, resource.get_class(), "embedded" if embedded else resource.resource_path])
			if embedded:
				var use: String = "%s.%s" % [prefix, key]
				if _first_use.has(resource):
					_shared.append("%s shares %s" % [use, _first_use[resource]])
				else:
					_first_use[resource] = use
				if depth < 6:
					_props(prefix, resource, depth + 1)
		else:
			_out.append("%s%s%s = %s" % [prefix, indent, key, var_to_str(value)])


## Auto names such as @CollisionShape3D@1234 carry a counter that differs between runs.
func _clean(path: String) -> String:
	var regex: RegEx = RegEx.create_from_string("@(\\w+)@\\d+")
	return regex.sub(path, "@$1@", true)
