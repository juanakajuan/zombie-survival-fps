extends SceneTree
## One-shot converter: game/level/arena.tscn to game/level/arena_layout.gd.
## Usage: godot --headless --path . -s tools/tscn_to_layout.gd
## It stops with an error on a node shape it does not know, so nothing is dropped silently.

const SOURCE: String = "res://game/level/arena.tscn"
const TARGET: String = "res://game/level/arena_layout.gd"
const LAMP_SCENE: String = "res://game/level/lamp.tscn"
const MATERIALS: Dictionary[String, String] = {
	"res://game/level/materials/ground.tres": "LevelBuilder.GROUND",
	"res://game/level/materials/wall.tres": "LevelBuilder.WALL",
	"res://game/level/materials/cover.tres": "LevelBuilder.COVER",
	"res://game/level/materials/platform.tres": "LevelBuilder.PLATFORM",
	"res://game/level/materials/crate.tres": "LevelBuilder.CRATE",
}
const WEAPONS: Dictionary[StringName, String] = {
	&"pistol": "Arsenal.pistol()",
	&"smg": "Arsenal.smg()",
	&"shotgun": "Arsenal.shotgun()",
	&"rifle": "Arsenal.rifle()",
	&"lmg": "Arsenal.lmg()",
	&"marksman": "Arsenal.marksman()",
}

var _state: SceneState
var _lines: PackedStringArray = []
## Node path in the scene to the GDScript variable that holds it.
var _vars: Dictionary[String, String] = {"": "arena"}
var _consumed: Dictionary[int, bool] = {}


func _init() -> void:
	var scene: PackedScene = load(SOURCE)
	_state = scene.get_state()
	_lines.append("class_name ArenaLayout")
	_lines.append("extends RefCounted")
	_lines.append("## The arena, one call per node. Generated once from the old arena.tscn, then kept by hand.")
	_lines.append("")
	_lines.append("")
	_lines.append("static func build(b: LevelBuilder) -> void:")
	_lines.append("\tvar arena: Node3D = b.root")
	for index: int in range(1, _state.get_node_count()):
		if not _consumed.has(index):
			_emit(index)
	var file: FileAccess = FileAccess.open(TARGET, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("wrote %s: %d lines" % [TARGET, _lines.size()])
	quit(0)


func _emit(index: int) -> void:
	var path: String = _path(index)
	var parent_path: String = _parent_path(index)
	var parent_var: String = _vars[parent_path]
	var node_name: String = _state.get_node_name(index)
	var props: Dictionary[String, Variant] = _props(index)
	var script_path: String = ""
	if props.has("script"):
		var script: Script = props["script"]
		script_path = script.resource_path
		props.erase("script")
	var instance: PackedScene = _state.get_node_instance(index)
	var type: String = _state.get_node_type(index)
	var call_text: String = ""
	var node_type: String = ""
	if instance != null and instance.resource_path == LAMP_SCENE:
		var at: Transform3D = _take(props, "transform", Transform3D.IDENTITY)
		_require(at.basis == Basis.IDENTITY, path, "a lamp with a rotation")
		call_text = "b.lamp(%s, &\"%s\", %s)" % [parent_var, node_name, _vec(at.origin)]
	elif type == "StaticBody3D" and script_path == "" and _is_block(index):
		var at: Transform3D = _take(props, "transform", Transform3D.IDENTITY)
		var shape_index: int = _child(index, "Shape")
		var mesh_index: int = _child(index, "Mesh")
		var shape: BoxShape3D = _props(shape_index)["shape"]
		var mesh_props: Dictionary[String, Variant] = _props(mesh_index)
		var mesh: BoxMesh = mesh_props["mesh"]
		var material: Material = mesh_props["material_override"]
		_require(shape.size == mesh.size, path, "a collision box and a mesh box of different sizes")
		_require(MATERIALS.has(material.resource_path), path, "an unknown material %s" % material.resource_path)
		_consumed[shape_index] = true
		_consumed[mesh_index] = true
		call_text = "b.block(%s, &\"%s\", %s, %s, %s)" % [parent_var, node_name, _vec(shape.size), _xform(at), MATERIALS[material.resource_path]]
		node_type = "StaticBody3D"
	elif script_path != "":
		_drop_station_defaults(props)
		var at: Transform3D = _take(props, "transform", Transform3D.IDENTITY)
		match script_path:
			"res://game/station/wall_buy.gd":
				var weapon_id: StringName = _take(props, "weapon_id", &"")
				_require(WEAPONS.has(weapon_id), path, "an unknown weapon id %s" % weapon_id)
				call_text = "b.wall_buy(%s, &\"%s\", %s, %d, %s)" % [parent_var, node_name, WEAPONS[weapon_id], _take(props, "price", 0), _xform(at)]
			"res://game/station/perk_machine.gd":
				var perk: int = _take(props, "perk", 0)
				call_text = "b.perk_machine(%s, &\"%s\", Perks.Kind.%s, %d, %s)" % [parent_var, node_name, Perks.Kind.find_key(perk), _take(props, "price", 0), _xform(at)]
			"res://game/station/upgrade_machine.gd":
				call_text = "b.upgrade_machine(%s, &\"%s\", %s)" % [parent_var, node_name, _xform(at)]
			"res://game/station/door.gd":
				var zone: StringName = _take(props, "zone", &"")
				call_text = "b.door(%s, &\"%s\", LevelBuilder.Zone.%s, %d, %s)" % [parent_var, node_name, String(zone).to_upper(), _take(props, "price", 0), _xform(at)]
			"res://game/station/power_switch.gd":
				call_text = "b.power_switch(%s, &\"%s\", %s)" % [parent_var, node_name, _xform(at)]
			"res://game/station/mystery_box.gd":
				_require(at == Transform3D.IDENTITY, path, "a box away from its crate center")
				call_text = "b.mystery_box(%s, &\"%s\")" % [parent_var, node_name]
			"res://game/station/cache.gd":
				call_text = "b.cache(%s, &\"%s\", %s)" % [parent_var, node_name, _xform(at)]
			"res://game/level/sigil.gd":
				_require(at.basis == Basis.IDENTITY, path, "a sigil with a rotation")
				call_text = "b.sigil(%s, &\"%s\", %s)" % [parent_var, node_name, _vec(at.origin)]
			"res://game/level/secret.gd":
				_require(at == Transform3D.IDENTITY, path, "a moved secret root")
				call_text = "b.secret(%s, &\"%s\")" % [parent_var, node_name]
				node_type = "Secret"
			_:
				_require(false, path, "an unknown script %s" % script_path)
	elif type == "Marker3D":
		var at: Transform3D = _take(props, "transform", Transform3D.IDENTITY)
		_require(at.basis == Basis.IDENTITY, path, "a marker with a rotation")
		call_text = "b.marker(%s, &\"%s\", %s)" % [parent_var, node_name, _vec(at.origin)]
	elif type == "Node3D" and props.is_empty():
		if parent_path == "ZombieSpawns":
			call_text = "b.spawn_group(%s, LevelBuilder.Zone.%s)" % [parent_var, node_name.to_upper()]
		else:
			call_text = "b.group(%s, &\"%s\")" % [parent_var, node_name]
		node_type = "Node3D"
	else:
		_emit_raw(index, type, node_name, parent_var, props)
		return
	_require(props.is_empty(), path, "properties the constructor does not take: %s" % ", ".join(props.keys()))
	if _has_children(index) and node_type != "":
		var var_name: String = _var_name(node_name)
		_vars[path] = var_name
		_lines.append("\tvar %s: %s = %s" % [var_name, node_type, call_text])
	else:
		_lines.append("\t" + call_text)


## The fallback for nodes with no constructor: the engine type and each property the scene sets.
func _emit_raw(index: int, type: String, node_name: String, parent_var: String, props: Dictionary[String, Variant]) -> void:
	var var_name: String = _var_name(node_name)
	_vars[_path(index)] = var_name
	_lines.append("\tvar %s: %s = %s.new()" % [var_name, type, type])
	_lines.append("\t%s.name = &\"%s\"" % [var_name, node_name])
	for key: String in props:
		_lines.append("\t%s.%s = %s" % [var_name, key, _value(type, key, props[key])])
	_lines.append("\tb.add(%s, %s)" % [parent_var, var_name])


func _value(owner_class: String, key: String, value: Variant) -> String:
	if value is Resource:
		var resource: Resource = value
		return _resource(resource)
	if value is int:
		var number: int = value
		var constant: String = _enum_constant(owner_class, key, number)
		if constant != "":
			return constant
	if value is Transform3D:
		var at: Transform3D = value
		return _xform(at)
	return var_to_str(value)


## Builds an embedded resource inline and returns the variable name.
func _resource(resource: Resource) -> String:
	_require(resource.resource_path == "" or resource.resource_path.contains("::"), str(resource), "a file resource in a raw node")
	var type: String = resource.get_class()
	var var_name: String = _var_name(type)
	_vars["::%s" % var_name] = var_name
	var assigns: PackedStringArray = []
	for property: Dictionary in resource.get_property_list():
		var usage: int = property["usage"]
		var key: String = property["name"]
		if usage & PROPERTY_USAGE_STORAGE == 0 or key.begins_with("resource_") or key == "script":
			continue
		var value: Variant = resource.get(key)
		if value == ClassDB.class_get_property_default_value(type, key):
			continue
		assigns.append("\t%s.%s = %s" % [var_name, key, _value(type, key, value)])
	_lines.append("\tvar %s: %s = %s.new()" % [var_name, type, type])
	_lines.append_array(assigns)
	return var_name


## "Environment.BG_SKY" for background_mode 2. "" when the property is not an engine enum.
## The property info has no enum name, so it comes from the setter argument.
func _enum_constant(owner_class: String, key: String, value: int) -> String:
	var setter: StringName = ClassDB.class_get_property_setter(owner_class, key)
	for method: Dictionary in ClassDB.class_get_method_list(owner_class):
		if method["name"] != setter:
			continue
		var args: Array = method["args"]
		var arg: Dictionary = args[args.size() - 1]
		var enum_name: String = arg["class_name"]
		if not enum_name.contains("."):
			return ""
		var parts: PackedStringArray = enum_name.split(".")
		for constant: String in ClassDB.class_get_enum_constants(parts[0], parts[1]):
			if ClassDB.class_get_integer_constant(parts[0], constant) == value:
				return "%s.%s" % [parts[0], constant]
	return ""


## The Area3D values that Station._init sets. The scene repeats them on each station.
func _drop_station_defaults(props: Dictionary[String, Variant]) -> void:
	for key: String in ["collision_layer", "collision_mask", "monitoring"]:
		if not props.has(key):
			continue
		var expected: Variant = {"collision_layer": Layers.INTERACT, "collision_mask": 0, "monitoring": false}[key]
		if props[key] == expected:
			props.erase(key)


func _is_block(index: int) -> bool:
	var shape_index: int = _child(index, "Shape")
	var mesh_index: int = _child(index, "Mesh")
	if shape_index < 0 or mesh_index < 0:
		return false
	var shape_props: Dictionary[String, Variant] = _props(shape_index)
	var mesh_props: Dictionary[String, Variant] = _props(mesh_index)
	return shape_props.keys() == ["shape"] and shape_props["shape"] is BoxShape3D and mesh_props.size() == 2 and mesh_props.get("mesh") is BoxMesh and mesh_props.get("material_override") is Material


func _props(index: int) -> Dictionary[String, Variant]:
	var found: Dictionary[String, Variant] = {}
	for property: int in range(_state.get_node_property_count(index)):
		found[String(_state.get_node_property_name(index, property))] = _state.get_node_property_value(index, property)
	return found


func _take(props: Dictionary[String, Variant], key: String, fallback: Variant) -> Variant:
	var value: Variant = props.get(key, fallback)
	props.erase(key)
	return value


func _path(index: int) -> String:
	return String(_state.get_node_path(index)).trim_prefix("./").trim_prefix(".")


func _parent_path(index: int) -> String:
	return String(_state.get_node_path(index, true)).trim_prefix("./").trim_prefix(".")


func _children(index: int) -> Array[int]:
	var found: Array[int] = []
	var path: String = _path(index)
	for other: int in range(1, _state.get_node_count()):
		if _parent_path(other) == path:
			found.append(other)
	return found


func _child(index: int, child_name: String) -> int:
	for other: int in _children(index):
		if _state.get_node_name(other) == child_name:
			return other
	return -1


func _has_children(index: int) -> bool:
	for child: int in _children(index):
		if not _consumed.has(child):
			return true
	return false


func _var_name(node_name: String) -> String:
	var var_name: String = node_name.to_snake_case()
	var suffix: int = 2
	while _vars.values().has(var_name):
		var_name = "%s_%d" % [node_name.to_snake_case(), suffix]
		suffix += 1
	return var_name


func _vec(value: Vector3) -> String:
	return var_to_str(value)


func _xform(value: Transform3D) -> String:
	if value.basis == Basis.IDENTITY:
		return "Transform3D(Basis.IDENTITY, %s)" % _vec(value.origin)
	return "Transform3D(%s, %s, %s, %s)" % [_vec(value.basis.x), _vec(value.basis.y), _vec(value.basis.z), _vec(value.origin)]


func _require(ok: bool, path: String, what: String) -> void:
	if not ok:
		push_error("tscn_to_layout: %s has %s. Add a constructor to LevelBuilder or convert it by hand." % [path, what])
		quit(1)
