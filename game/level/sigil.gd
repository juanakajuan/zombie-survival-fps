@tool
class_name Sigil
extends StaticBody3D
## A glowing mark on a wall. A shot lights it. It also stops bullets. Its origin is on the wall face, and its +Z axis points out of the wall.

signal lit

const SIZE: Vector3 = Vector3(0.8, 0.8, 0.1)
const OFF_COLOR: Color = Color(0.25, 0.1, 0.35)
const ON_COLOR: Color = Color(0.85, 0.4, 1.0)

var is_lit: bool = false
## The children that _build() adds. They have no owner, so the editor does not save them in the scene.
var _built: Array[Node] = []


func _init() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0


func _ready() -> void:
	_build()


func light() -> void:
	if is_lit:
		return
	is_lit = true
	_build()
	lit.emit()


func _build() -> void:
	if not is_node_ready():
		return
	for node: Node in _built:
		node.free()
	_built.clear()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = SIZE
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	_add(shape_node)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ON_COLOR if is_lit else OFF_COLOR
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	_add(mesh_node)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = ON_COLOR if is_lit else OFF_COLOR
	glow.light_energy = 1.5 if is_lit else 0.4
	glow.omni_range = 5.0
	glow.position = Vector3(0.0, 0.0, 0.8)
	_add(glow)


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)
