extends TestCase

const COMPOUND_SCENE: PackedScene = preload("res://levels/compound.tscn")
## The foot and the top of each ramp, in level coordinates. Each ramp goes up toward -Z, the way the player looks at start.
const MEZZANINE_RAMP_FOOT := Vector3(-20.0, 0.0, 0.0)
const WATCHTOWER_RAMP_FOOT := Vector3(29.0, 0.0, -9.0)
const HIGH_FLOOR_HEIGHT := 4.0
## The floor plans of the two buildings with doors, as x and z.
const WAREHOUSE := Rect2(-22.0, -22.0, 34.0, 26.0)
const OFFICE := Rect2(-34.0, 22.0, 14.0, 12.0)


func test_every_spawn_point_has_a_path_to_the_player_start_once_the_doors_are_open() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var start := (level.get_node("Player") as Player).global_position
	var spawns := spawn_points_in(level)
	assert_eq(spawns.size(), 6, "spawn points")
	var closed := spawns.filter(func(spawn: SpawnPoint) -> bool: return not spawn.is_active())
	assert_eq(closed.size(), 2, "spawn points that wait for a door")
	for spawn: SpawnPoint in spawns:
		if spawn.is_active():
			assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start" % spawn.name)
		else:
			assert_true(not _path_reaches(level, spawn.global_position, start), "%s has a path to the player start through a closed door" % spawn.name)
	for node: Node in level.get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).open()
	await run_seconds(1.0)
	for spawn: SpawnPoint in spawns:
		assert_true(spawn.is_active(), "%s is active with its doors open" % spawn.name)
		assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start with the doors open" % spawn.name)


func test_the_player_start_and_the_stations_are_outside_both_buildings() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var player := level.get_node("Player") as Player
	var points: Array[Vector3] = [player.global_position]
	for station: BuyStation in _shops(level):
		points.append(station.global_position)
	for at: Vector3 in points:
		assert_true(not WAREHOUSE.has_point(Vector2(at.x, at.z)), "%s is outside the warehouse" % at)
		assert_true(not OFFICE.has_point(Vector2(at.x, at.z)), "%s is outside the office" % at)


func test_the_player_walks_up_the_mezzanine_ramp_onto_the_mezzanine() -> void:
	await _assert_walks_up_the_ramp_from(MEZZANINE_RAMP_FOOT, "mezzanine")


func test_the_player_walks_up_the_watchtower_ramp_onto_the_watchtower() -> void:
	await _assert_walks_up_the_ramp_from(WATCHTOWER_RAMP_FOOT, "watchtower")


func test_round_1_starts_and_the_level_runs_for_5_seconds() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	assert_eq((level.get_node("RoundManager") as RoundManager).round_number, 1, "round number")
	await run_seconds(5.0)


func test_the_level_has_an_ammo_station_and_a_weapon_station_near_the_player_start() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var player := level.get_node("Player") as Player
	assert_true(sells(level, AmmoItem), "an ammo station")
	assert_true(sells_weapon(level, "SMG"), "a weapon station that sells the SMG")
	for station: BuyStation in _shops(level):
		assert_true(station.global_position.distance_to(player.global_position) < 10.0, "%s is in the yard near the start" % station.name)


func _shops(level: Level) -> Array[BuyStation]:
	return stations_in(level).filter(func(station: BuyStation) -> bool: return not station.item is DoorItem)


func _assert_walks_up_the_ramp_from(foot: Vector3, floor_name: String) -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var player := level.get_node("Player") as Player
	player.global_position = foot
	Input.action_press("move_forward")
	await run_seconds(5.0)
	assert_almost_eq(player.global_position.y, HIGH_FLOOR_HEIGHT, 0.1, "player height after walking up to the %s" % floor_name)


func _path_reaches(level: Level, from: Vector3, to: Vector3) -> bool:
	var map := level.navigation.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.0
