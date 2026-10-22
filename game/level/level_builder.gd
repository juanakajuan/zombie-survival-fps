class_name LevelBuilder
extends RefCounted
## Typed constructors for a level built in code. Each node gets the level root as owner, so find_children finds it as it did in the scene.

enum Zone { YARD, WAREHOUSE, COURTYARD }

const GROUND: Material = preload("res://game/level/materials/ground.tres")
const WALL: Material = preload("res://game/level/materials/wall.tres")
const COVER: Material = preload("res://game/level/materials/cover.tres")
const PLATFORM: Material = preload("res://game/level/materials/platform.tres")
const CRATE: Material = preload("res://game/level/materials/crate.tres")

const LAMP_POST_SIZE: Vector3 = Vector3(0.2, 3.5, 0.2)
const LAMP_BULB_SIZE: Vector3 = Vector3(0.4, 0.25, 0.4)
const LAMP_COLOR: Color = Color(1, 0.72, 0.4, 1)

## Every lamp shares these resources, as the instances of the lamp scene did.
static var _post_shape: BoxShape3D = _box_shape(LAMP_POST_SIZE)
static var _post_mesh: BoxMesh = _box_mesh(LAMP_POST_SIZE)
static var _bulb_mesh: BoxMesh = _box_mesh(LAMP_BULB_SIZE)
static var _bulb_material: StandardMaterial3D = _unshaded(LAMP_COLOR)

var root: Node3D


func _init(level_root: Node3D) -> void:
	root = level_root


static func zone_id(zone: Zone) -> StringName:
	var key: String = Zone.find_key(zone)
	return StringName(key.to_lower())


func add(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	node.owner = root
	return node


func group(parent: Node, node_name: StringName) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	add(parent, node)
	return node


## The collision box and the mesh box come from one size, so they cannot differ.
func block(parent: Node, node_name: StringName, size: Vector3, at: Transform3D, material: Material) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.transform = at
	add(parent, body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = _box_shape(size)
	add(body, shape_node)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	mesh_node.material_override = material
	mesh_node.mesh = _box_mesh(size)
	add(body, mesh_node)
	return body


func lamp(parent: Node, node_name: StringName, at: Vector3) -> Node3D:
	var lamp_root: Node3D = group(parent, node_name)
	lamp_root.position = at
	var post: StaticBody3D = StaticBody3D.new()
	post.name = "Post"
	post.position = Vector3(0, 1.75, 0)
	_add_owned(lamp_root, lamp_root, post)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = _post_shape
	_add_owned(post, lamp_root, shape_node)
	var post_mesh_node: MeshInstance3D = MeshInstance3D.new()
	post_mesh_node.name = "Mesh"
	post_mesh_node.material_override = WALL
	post_mesh_node.mesh = _post_mesh
	_add_owned(post, lamp_root, post_mesh_node)
	var bulb: MeshInstance3D = MeshInstance3D.new()
	bulb.name = "Bulb"
	bulb.position = Vector3(0, 3.6, 0)
	bulb.material_override = _bulb_material
	bulb.mesh = _bulb_mesh
	_add_owned(lamp_root, lamp_root, bulb)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 3.3, 0)
	light.light_color = LAMP_COLOR
	light.light_energy = 2.0
	light.omni_range = 14.0
	_add_owned(lamp_root, lamp_root, light)
	return lamp_root


func wall_buy(parent: Node, node_name: StringName, weapon: WeaponDef, price: int, at: Transform3D) -> WallBuy:
	var station: WallBuy = WallBuy.new()
	station.weapon_id = weapon.id
	station.price = price
	_place(parent, node_name, station, at)
	return station


func perk_machine(parent: Node, node_name: StringName, perk: Perks.Kind, price: int, at: Transform3D) -> PerkMachine:
	var station: PerkMachine = PerkMachine.new()
	station.perk = perk
	station.price = price
	_place(parent, node_name, station, at)
	return station


func upgrade_machine(parent: Node, node_name: StringName, at: Transform3D) -> UpgradeMachine:
	var station: UpgradeMachine = UpgradeMachine.new()
	_place(parent, node_name, station, at)
	return station


func door(parent: Node, node_name: StringName, zone: Zone, price: int, at: Transform3D) -> Door:
	var station: Door = Door.new()
	station.zone = zone_id(zone)
	station.price = price
	_place(parent, node_name, station, at)
	return station


func power_switch(parent: Node, node_name: StringName, at: Transform3D) -> PowerSwitch:
	var station: PowerSwitch = PowerSwitch.new()
	_place(parent, node_name, station, at)
	return station


## The box sits at the center of its crate, so it takes no transform.
func mystery_box(crate: StaticBody3D, node_name: StringName) -> MysteryBox:
	var station: MysteryBox = MysteryBox.new()
	_place(crate, node_name, station, Transform3D.IDENTITY)
	return station


func cache(secret_root: Secret, node_name: StringName, at: Transform3D) -> Cache:
	var station: Cache = Cache.new()
	_place(secret_root, node_name, station, at)
	return station


func secret(parent: Node, node_name: StringName) -> Secret:
	var node: Secret = Secret.new()
	node.name = node_name
	add(parent, node)
	return node


func sigil(secret_root: Secret, node_name: StringName, at: Vector3) -> Sigil:
	var node: Sigil = Sigil.new()
	node.name = node_name
	node.position = at
	add(secret_root, node)
	return node


func spawn_group(parent: Node, zone: Zone) -> Node3D:
	return group(parent, String(zone_id(zone)).capitalize())


func marker(parent: Node, node_name: StringName, at: Vector3) -> Marker3D:
	var node: Marker3D = Marker3D.new()
	node.name = node_name
	node.position = at
	add(parent, node)
	return node


func _place(parent: Node, node_name: StringName, station: Station, at: Transform3D) -> void:
	station.name = node_name
	station.transform = at
	add(parent, station)


func _add_owned(parent: Node, owner_node: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = owner_node


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	return shape


static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
