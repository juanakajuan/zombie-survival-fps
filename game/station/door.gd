@tool
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
@export var zone: StringName = &"":
	set(id):
		zone = id
		_build()
@export_range(0, 10000, 10) var price: int = 0:
	set(cost):
		price = cost
		_build()

var is_open: bool = false
## The children that _build() adds. They have no owner, so the editor does not save them in the scene.
var _built: Array[Node] = []


func _ready() -> void:
	_build()


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if is_open:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")
	return Station.Offer.new(Station.Offer.Kind.DOOR, price, "Open %s" % String(zone).capitalize())


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.DOOR or is_open:
		return
	is_open = true
	collision_layer = 0
	_clear()
	opened.emit(zone)


func _clear() -> void:
	for node: Node in _built:
		node.free()
	_built.clear()


func _build() -> void:
	if not is_node_ready() or is_open:
		return
	_clear()
	var area_shape: BoxShape3D = BoxShape3D.new()
	area_shape.size = Vector3(GAP_SIZE.x, GAP_SIZE.y, AREA_DEPTH)
	var area: CollisionShape3D = CollisionShape3D.new()
	area.shape = area_shape
	area.position = Vector3(0.0, 0.0, AREA_DEPTH * 0.5 - GAP_SIZE.z * 0.5)
	_add(area)
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.collision_layer = Layers.WORLD
	blocker.collision_mask = 0
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = GAP_SIZE
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = shape
	blocker.add_child(shape_node)
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = GAP_SIZE
	var slab_material: StandardMaterial3D = StandardMaterial3D.new()
	slab_material.albedo_color = SLAB_COLOR
	slab_material.roughness = 0.8
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = "Mesh"
	slab.mesh = slab_mesh
	slab.material_override = slab_material
	blocker.add_child(slab)
	_add(blocker)
	var label: Label3D = Label3D.new()
	label.text = "%s\n%d" % [String(zone).capitalize(), price]
	label.modulate = CAPTION_COLOR
	label.outline_size = 0
	label.pixel_size = 0.003
	label.font_size = 48
	label.position = Vector3(0.0, 0.2, GAP_SIZE.z * 0.5 + 0.02)
	_add(label)


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)
