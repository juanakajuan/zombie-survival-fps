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

var _collision: CollisionShape3D
var _box: MeshInstance3D
var _glow: OmniLight3D


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
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position = Vector3(0.0, 0.0, AREA_SIZE.z * 0.5)
	add_child(_collision)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = BOX_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GLOW_COLOR
	_box = MeshInstance3D.new()
	_box.mesh = mesh
	_box.material_override = material
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.position = Vector3(0.0, 0.0, BOX_SIZE.z * 0.5)
	add_child(_box)
	_glow = OmniLight3D.new()
	_glow.light_color = GLOW_COLOR
	_glow.light_energy = 1.5
	_glow.omni_range = 4.0
	_glow.position = Vector3(0.0, 0.3, 0.8)
	add_child(_glow)


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if not revealed or is_taken:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")
	return Station.Offer.new(Station.Offer.Kind.CACHE, 0, "Take the cache")


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.CACHE or is_taken:
		return
	is_taken = true
	_collision.free()
	_box.free()
	_glow.free()
	taken.emit()
