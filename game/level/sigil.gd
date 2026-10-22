class_name Sigil
extends StaticBody3D
## A glowing mark on a wall. A shot lights it. It also stops bullets. Its origin is on the wall face, and its +Z axis points out of the wall.

signal lit

const SIZE: Vector3 = Vector3(0.8, 0.8, 0.1)
const OFF_COLOR: Color = Color(0.25, 0.1, 0.35)
const ON_COLOR: Color = Color(0.85, 0.4, 1.0)

var is_lit: bool = false

var _material: StandardMaterial3D
var _glow: OmniLight3D


func _init() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0


func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = SIZE
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	add_child(shape_node)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = SIZE
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	mesh_node.mesh = mesh
	mesh_node.material_override = _material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	add_child(mesh_node)
	_glow = OmniLight3D.new()
	_glow.omni_range = 5.0
	_glow.position = Vector3(0.0, 0.0, 0.8)
	add_child(_glow)
	_show_state()


func light() -> void:
	if is_lit:
		return
	is_lit = true
	_show_state()
	lit.emit()


func _show_state() -> void:
	var color: Color = ON_COLOR if is_lit else OFF_COLOR
	_material.albedo_color = color
	_glow.light_color = color
	_glow.light_energy = 1.5 if is_lit else 0.4
