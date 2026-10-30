class_name TestCase
extends Node
## Base class for tests. tests/run_tests.gd adds a fresh instance to the tree for each `test_*` method.
## A test method may be a coroutine. Use `await physics_frames(n)` to let the physics engine run.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://zombie/zombie.tscn")
const STATION_SCENE: PackedScene = preload("res://economy/buy_station.tscn")
const PICKUP_SCENE: PackedScene = preload("res://pickups/pickup.tscn")
const DUMMY_SCENE: PackedScene = preload("res://targets/target_dummy.tscn")
const LEVEL_SCENE: PackedScene = preload("res://levels/test_range.tscn")
const ROUND_SETTINGS: RoundSettings = preload("res://rounds/round_settings.tres")

var failures: PackedStringArray = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s ± %s, got %s" % [message, expected, tolerance, actual])


func physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func run_seconds(seconds: float) -> void:
	await physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


## Sends one press of an Input Map action as an input event, as a key or wheel notch does. `Input.action_press()` sends none.
func press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## The lowest (x) and highest (y) value that `value` gives over `seconds` of physics frames.
func sample_range(value: Callable, seconds: float) -> Vector2:
	var lowest := INF
	var highest := -INF
	for _i: int in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frames(1)
		var sample: float = value.call()
		lowest = minf(lowest, sample)
		highest = maxf(highest, sample)
	return Vector2(lowest, highest)


## Adds a 200 m floor at y = 0 and a player on it, then runs `settle_frames` physics frames.
func spawn_player(at: Vector3 = Vector3.ZERO, settle_frames: int = 1) -> Player:
	add_child(_box(Vector3(200.0, 1.0, 200.0), Vector3(0.0, -0.5, 0.0)))
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	add_child(player)
	await physics_frames(settle_frames)
	return player


## A round 1 zombie of the game's round settings. Without a target, it stands still.
func spawn_zombie(at: Vector3, target: Node3D = null) -> Zombie:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	zombie.configure(ROUND_SETTINGS.zombie_speed(1), ROUND_SETTINGS.zombie_health(1), target)
	zombie.position = at
	zombie.drops = null
	add_child(zombie)
	return zombie


func spawn_pickup(item: BuyItem, at: Vector3, lifetime: float = 0.0) -> Pickup:
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item
	pickup.lifetime = lifetime
	pickup.position = at
	add_child(pickup)
	return pickup


## The pickups that are children of `parent`.
func pickups_in(parent: Node) -> Array[Pickup]:
	var found: Array[Pickup] = []
	for child: Node in parent.get_children():
		if child is Pickup:
			found.append(child as Pickup)
	return found


func spawn_dummy(at: Vector3) -> TargetDummy:
	var dummy := DUMMY_SCENE.instantiate() as TargetDummy
	dummy.position = at
	add_child(dummy)
	await physics_frames(2)
	return dummy


func spawn_station(at: Vector3) -> BuyStation:
	var station := STATION_SCENE.instantiate() as BuyStation
	station.position = at
	add_child(station)
	return station


func stations_in(level: Level) -> Array[BuyStation]:
	var found: Array[BuyStation] = []
	for node: Node in level.find_children("*", "StaticBody3D", true, false):
		if node is BuyStation:
			found.append(node as BuyStation)
	return found


func spawn_points_in(level: Level) -> Array[SpawnPoint]:
	var found: Array[SpawnPoint] = []
	for node: Node in level.get_node("RoundManager").get_children():
		if node is SpawnPoint:
			found.append(node as SpawnPoint)
	return found


## Whether a buy station of the level sells an item of this class.
func sells(level: Level, item_class: GDScript) -> bool:
	for station: BuyStation in stations_in(level):
		if is_instance_of(station.item, item_class):
			return true
	return false


## Whether a buy station of the level sells the weapon with this display name.
func sells_weapon(level: Level, weapon_name: String) -> bool:
	for station: BuyStation in stations_in(level):
		var item := station.item as WeaponItem
		if item != null and item.weapon.display_name == weapon_name:
			return true
	return false


## Turns the player's view to `point` with one mouse motion.
func look_at_point(player: Player, point: Vector3) -> void:
	player.look(player.mouse_delta_to(point))


## Adds a level (the test range by default) and returns when the navigation map answers queries from its baked navmesh.
## `round_settings` replaces the round settings before round 1 starts.
func spawn_level(round_settings: RoundSettings = null, scene: PackedScene = LEVEL_SCENE) -> Level:
	var level := scene.instantiate() as Level
	if round_settings != null:
		(level.get_node("RoundManager") as RoundManager).settings = round_settings
	add_child(level)
	await level.navigation.bake_finished
	# The server syncs the new mesh on a worker thread, so it takes a number of physics frames that is not known.
	var map := level.navigation.get_navigation_map()
	for _i: int in 60:
		await physics_frames(1)
		# A query before the map's first sync logs an error.
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		if NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO) == level.navigation.get_rid():
			return level
	failures.append("the navigation map never answered queries from the level navmesh")
	return level


## Bakes a 60 m navigation floor at y = 0, with a 10 m wall across x at z = 0 when `with_wall` is true.
## Returns when the navigation map answers path queries.
func spawn_nav_world(with_wall: bool = false) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# A mesh with a cell size that is not the map's makes the server log "cell size mismatch".
	var map := get_viewport().find_world_3d().navigation_map
	mesh.cell_size = NavigationServer3D.map_get_cell_size(map)
	mesh.cell_height = NavigationServer3D.map_get_cell_height(map)
	mesh.agent_radius = 0.5
	mesh.agent_max_climb = 0.25
	mesh.agent_height = 2.0
	region.navigation_mesh = mesh
	region.add_child(_box(Vector3(60.0, 1.0, 60.0), Vector3(0.0, -0.5, 0.0)))
	if with_wall:
		region.add_child(_box(Vector3(10.0, 2.0, 0.5), Vector3(0.0, 1.0, 0.0)))
	add_child(region)
	region.bake_navigation_mesh(false)
	# The navigation server needs several physics frames before it can answer path queries from the new mesh.
	for _i: int in 60:
		await physics_frames(1)
		if not NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, -4.0), true).is_empty():
			return region
	failures.append("navigation map never became ready")
	return region


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = at
	body.add_child(shape)
	return body
