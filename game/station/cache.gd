class_name Cache
extends Station
## A free reward behind the secret panel. It cannot be used until reveal(). The player takes it one time.
## accept() frees every child, so nothing else may add a child to a Cache.

signal taken

const BOX_SIZE: Vector3 = Vector3(0.9, 0.5, 0.5)
## The area is taller than the box, so the ray at eye height finds it.
const AREA_SIZE: Vector3 = Vector3(1.2, 1.8, 0.9)
const GLOW_COLOR: Color = Color(1.0, 0.8, 0.25)

var revealed: bool = false
var is_taken: bool = false


func _init() -> void:
	super()
	collision_layer = 0


func reveal() -> void:
	if revealed:
		return
	revealed = true
	collision_layer = Layers.INTERACT
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = AREA_SIZE
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, AREA_SIZE.z * 0.5)
	add_child(collision)
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
	add_child(box)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = GLOW_COLOR
	glow.light_energy = 1.5
	glow.omni_range = 4.0
	glow.position = Vector3(0.0, 0.3, 0.8)
	add_child(glow)


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if not revealed or is_taken:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")
	return Station.Offer.new(Station.Offer.Kind.CACHE, 0, "Take the cache")


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.CACHE or is_taken:
		return
	is_taken = true
	for node: Node in get_children():
		node.free()
	taken.emit()
