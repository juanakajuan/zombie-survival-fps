@tool
class_name Cache
extends Station
## A free reward behind the secret panel. It cannot be used until reveal(). The player takes it one time.

signal taken

const BOX_SIZE: Vector3 = Vector3(0.9, 0.5, 0.5)
## The area is taller than the box, so the ray at eye height finds it.
const AREA_SIZE: Vector3 = Vector3(1.2, 1.8, 0.9)
const GLOW_COLOR: Color = Color(1.0, 0.8, 0.25)

var revealed: bool = false
var is_taken: bool = false
## The children that _build() adds. They have no owner, so the editor does not save them in the scene.
var _built: Array[Node] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		revealed = true
	else:
		collision_layer = 0
	_build()


func reveal() -> void:
	if revealed:
		return
	revealed = true
	collision_layer = Layers.INTERACT
	_build()


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if not revealed or is_taken:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")
	return Station.Offer.new(Station.Offer.Kind.CACHE, 0, "Take the cache")


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.CACHE or is_taken:
		return
	is_taken = true
	_build()
	taken.emit()


func _build() -> void:
	if not is_node_ready():
		return
	for node: Node in _built:
		node.free()
	_built.clear()
	if not revealed or is_taken:
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = AREA_SIZE
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, AREA_SIZE.z * 0.5)
	_add(collision)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = BOX_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GLOW_COLOR
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = mesh
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.position = Vector3(0.0, 0.0, BOX_SIZE.z * 0.5)
	_add(box)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = GLOW_COLOR
	glow.light_energy = 1.5
	glow.omni_range = 4.0
	glow.position = Vector3(0.0, 0.3, 0.8)
	_add(glow)


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)
