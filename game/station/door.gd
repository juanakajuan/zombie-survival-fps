class_name Door
extends Station
## A door in a wall gap. The player buys it one time. Its origin is the gap center, and its +Z axis points toward the zone that is open.

signal opened(zone: StringName)

const GAP_SIZE: Vector3 = Vector3(4.0, 3.0, 1.0)
## The interact area stands out from the gap, so the ray finds it before the blocker.
const AREA_DEPTH: float = 3.0
const SLAB_COLOR: Color = Color(0.2, 0.1, 0.07)
const CAPTION_COLOR: Color = Color(1.0, 0.7, 0.35)

## The id of the zone that this door opens. It is the lower case name of a node under ZombieSpawns.
var zone: StringName
var price: int
var is_open: bool = false

var _area: CollisionShape3D
var _blocker: StaticBody3D
var _label: Label3D


func _init(door_zone: StringName, door_price: int) -> void:
	super()
	zone = door_zone
	price = door_price


func _ready() -> void:
	var area_shape: BoxShape3D = BoxShape3D.new()
	area_shape.size = Vector3(GAP_SIZE.x, GAP_SIZE.y, AREA_DEPTH)
	_area = CollisionShape3D.new()
	_area.shape = area_shape
	_area.position = Vector3(0.0, 0.0, AREA_DEPTH * 0.5 - GAP_SIZE.z * 0.5)
	add_child(_area)
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = Layers.WORLD
	_blocker.collision_mask = 0
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = GAP_SIZE
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = shape
	_blocker.add_child(shape_node)
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = GAP_SIZE
	var slab_material: StandardMaterial3D = StandardMaterial3D.new()
	slab_material.albedo_color = SLAB_COLOR
	slab_material.roughness = 0.8
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = "Mesh"
	slab.mesh = slab_mesh
	slab.material_override = slab_material
	_blocker.add_child(slab)
	add_child(_blocker)
	_label = Label3D.new()
	_label.text = "%s\n%d" % [String(zone).capitalize(), price]
	_label.modulate = CAPTION_COLOR
	_label.outline_size = 0
	_label.pixel_size = 0.003
	_label.font_size = 48
	_label.position = Vector3(0.0, 0.2, GAP_SIZE.z * 0.5 + 0.02)
	add_child(_label)


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if is_open:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")
	return Station.Offer.new(Station.Offer.Kind.DOOR, price, "Open %s" % String(zone).capitalize())


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.DOOR or is_open:
		return
	is_open = true
	collision_layer = 0
	_area.free()
	_blocker.free()
	_label.free()
	opened.emit(zone)
