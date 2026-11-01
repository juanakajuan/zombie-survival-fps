extends TestCase

const PUMPKIN_HOLLOW_SCENE: PackedScene = preload("res://levels/pumpkin_hollow/pumpkin_hollow.tscn")
const SQUARE_XZ := Rect2(-12.0, -18.0, 24.0, 32.0)
const GARAGE_XZ := Rect2(-32.0, -18.0, 20.0, 28.0)
## The foot of the church ramp. The ramp goes up toward -Z onto the platform.
const CHURCH_RAMP_FOOT := Vector3(6.0, 0.0, -21.0)
const CHURCH_PLATFORM_HEIGHT := 0.45


func test_the_player_stands_on_the_imported_ground() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	await run_seconds(1.0)
	assert_almost_eq(level.player.global_position.y, 0.0, 0.05, "player height on the square")
	assert_true(level.player.is_on_floor(), "the player is on the floor")


func test_every_spawn_point_has_a_path_to_the_player_start_once_the_doors_are_open() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	var start := level.player.global_position
	var spawns := spawn_points_in(level)
	assert_eq(spawns.size(), 7, "spawn points")
	var closed := spawns.filter(func(spawn: SpawnPoint) -> bool: return not spawn.is_active())
	assert_eq(closed.size(), 4, "spawn points that wait for a door")
	for spawn: SpawnPoint in spawns:
		if spawn.is_active():
			assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start" % spawn.name)
	_open_all_doors(level)
	await run_seconds(1.0)
	for spawn: SpawnPoint in spawns:
		assert_true(spawn.is_active(), "%s is active with its doors open" % spawn.name)
		assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start with the doors open" % spawn.name)


func test_each_barricade_spawn_point_has_a_path_to_the_player_start_through_its_barricade() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	_open_all_doors(level)
	await run_seconds(1.0)
	var start := level.player.global_position
	var with_barricade: Array[SpawnPoint] = spawn_points_in(level).filter(func(point: SpawnPoint) -> bool: return point.barricade != null)
	assert_eq(with_barricade.size(), 6, "spawn points that name a barricade")
	for spawn: SpawnPoint in with_barricade:
		assert_true(not spawn.barricade.is_inside(spawn.global_position), "%s is outside its barricade" % spawn.name)
		var path := NavigationServer3D.map_get_path(level.navigation.get_navigation_map(), spawn.global_position, start, true)
		assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start" % spawn.name)
		assert_true(path_goes_inside(path, spawn.barricade), "the path of %s goes through its barricade" % spawn.name)


func test_the_square_has_the_starting_shops_and_the_wall_buys_are_spread_over_the_map() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	var start := level.player.global_position
	assert_true(sells(level, AmmoItem), "an ammo station")
	assert_true(sells_weapon(level, "SMG"), "a weapon station that sells the SMG")
	assert_true(sells_weapon(level, "SHOTGUN"), "a wall buy that sells the shotgun")
	assert_true(sells_weapon(level, "RIFLE"), "a wall buy that sells the rifle")
	assert_true(sells_weapon(level, "MACHINE GUN"), "a wall buy that sells the machine gun")
	for station: BuyStation in stations_in(level).filter(func(station: BuyStation) -> bool: return station.item is AmmoItem or (station.item is WeaponItem and not station is WallBuy)):
		assert_true(station.global_position.distance_to(start) < 10.0, "%s is near the start" % station.name)


func test_the_power_switch_is_in_the_garage_behind_its_door_and_powers_every_machine() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	var power := level.get_node("PowerSwitch") as PowerSwitch
	var start := level.player.global_position
	assert_true(GARAGE_XZ.has_point(Vector2(power.global_position.x, power.global_position.z)), "the switch is in the garage")
	(level.get_node("GarageDoor") as Door).open()
	await run_seconds(1.0)
	assert_true(_path_reaches(level, start, power.global_position + power.global_basis.z), "the switch has a path from the start")
	var machines: Array[BuyStation] = stations_in(level).filter(func(station: BuyStation) -> bool: return station.item is PerkItem or station.item is UpgradeItem)
	assert_eq(machines.size(), 6, "five perk machines and an upgrade machine")
	for machine: BuyStation in machines:
		assert_true(machine.power == power, "%s needs the switch" % machine.name)
		assert_true(not machine.has_power(), "%s has no power at the start" % machine.name)
	power.turn_on()
	for machine: BuyStation in machines:
		assert_true(machine.has_power(), "%s has power" % machine.name)


func test_the_weapon_box_starts_in_the_square_and_each_of_its_places_has_a_path_to_the_start() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	var box := level.get_node("WeaponBox") as WeaponBox
	var start := level.player.global_position
	assert_true(SQUARE_XZ.has_point(Vector2(box.global_position.x, box.global_position.z)), "the box starts in the square")
	assert_eq(box.places.size(), 4, "box places")
	_open_all_doors(level)
	await run_seconds(1.0)
	for place: Node3D in box.places:
		var front := place.global_position + place.global_basis.z * 1.3
		assert_true(_path_reaches(level, front, start), "the player can walk to the box at %s" % place.name)


func test_the_player_walks_up_the_church_ramp_onto_the_platform() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	level.player.global_position = CHURCH_RAMP_FOOT
	look_at_point(level.player, CHURCH_RAMP_FOOT + Vector3.FORWARD * 100.0)
	Input.action_press("move_forward")
	await run_seconds(1.5)
	assert_almost_eq(level.player.global_position.y, CHURCH_PLATFORM_HEIGHT, 0.05, "player height on the church platform")


func test_the_navmesh_answers_queries_when_the_level_loads_right_after_another_level() -> void:
	var first := await spawn_level()
	first.queue_free()
	await physics_frames(1)
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	var map := level.navigation.get_navigation_map()
	var start := level.player.global_position
	assert_eq(NavigationServer3D.map_get_closest_point_owner(map, start), level.navigation.get_rid(), "the region that owns the navmesh at the player start")


func test_round_1_starts_and_the_level_runs_for_5_seconds() -> void:
	var level := await spawn_level(null, PUMPKIN_HOLLOW_SCENE)
	assert_eq(level.round_manager.round_number, 1, "round number")
	await run_seconds(5.0)


func _open_all_doors(level: Level) -> void:
	for node: Node in level.get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).open()


func _path_reaches(level: Level, from: Vector3, to: Vector3) -> bool:
	var map := level.navigation.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.0
