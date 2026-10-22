@abstract
class_name Machine
extends Station
## A slab on a wall that sells one lasting thing. Its origin is on the wall face, and its +Z axis points out of the wall.

const SLAB_SIZE: Vector3 = Vector3(1.2, 1.7, 0.3)
## The interact area stands out from the wall, so the ray finds it before the wall.
const AREA_DEPTH: float = 0.7
const BODY_COLOR: Color = Color(0.06, 0.06, 0.07)
const OFF_COLOR: Color = Color(0.12, 0.12, 0.13)

var powered: bool = false:
	set(on):
		powered = on
		if is_node_ready():
			_show_power()

var _strip_material: StandardMaterial3D
var _label: Label3D
var _glow: OmniLight3D


func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(SLAB_SIZE.x, SLAB_SIZE.y, AREA_DEPTH)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, AREA_DEPTH * 0.5)
	add_child(collision)
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = SLAB_SIZE
	var slab_material: StandardMaterial3D = StandardMaterial3D.new()
	slab_material.albedo_color = BODY_COLOR
	slab_material.roughness = 0.6
	slab_material.metallic = 0.5
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.mesh = slab_mesh
	slab.material_override = slab_material
	slab.position = Vector3(0.0, 0.0, SLAB_SIZE.z * 0.5)
	add_child(slab)
	var strip_mesh: BoxMesh = BoxMesh.new()
	strip_mesh.size = Vector3(SLAB_SIZE.x * 0.8, 0.12, 0.02)
	_strip_material = StandardMaterial3D.new()
	_strip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var strip: MeshInstance3D = MeshInstance3D.new()
	strip.mesh = strip_mesh
	strip.material_override = _strip_material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(0.0, SLAB_SIZE.y * 0.5 - 0.25, SLAB_SIZE.z + 0.011)
	add_child(strip)
	_label = Label3D.new()
	_label.text = caption()
	_label.outline_size = 0
	_label.pixel_size = 0.004
	_label.font_size = 48
	_label.position = Vector3(0.0, 0.4, SLAB_SIZE.z + 0.012)
	add_child(_label)
	_glow = OmniLight3D.new()
	_glow.omni_range = 3.5
	_glow.position = Vector3(0.0, 0.0, SLAB_SIZE.z + 0.6)
	add_child(_glow)
	_show_power()


func offer(loadout: Loadout, perks: Perks) -> Station.Offer:
	if not powered:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "No power")
	return _offer(loadout, perks)


@abstract func _offer(loadout: Loadout, perks: Perks) -> Station.Offer


## The two lines on the slab.
@abstract func caption() -> String


@abstract func glow_color() -> Color


func _show_power() -> void:
	var color: Color = glow_color() if powered else OFF_COLOR
	_strip_material.albedo_color = color
	_label.modulate = color
	_glow.light_color = color
	_glow.light_energy = 1.2 if powered else 0.0
