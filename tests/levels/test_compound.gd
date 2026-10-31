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


func test_each_gate_spawn_point_has_a_path_to_the_player_start_through_its_barricade() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var start := (level.get_node("Player") as Player).global_position
	var with_barricade: Array[SpawnPoint] = spawn_points_in(level).filter(func(point: SpawnPoint) -> bool: return point.barricade != null)
	assert_eq(with_barricade.size(), 3, "spawn points that name a barricade")
	for spawn: SpawnPoint in with_barricade:
		assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start" % spawn.name)
		assert_true(not spawn.barricade.is_inside(spawn.global_position), "%s is outside its barricade" % spawn.name)
		assert_true(spawn.barricade.is_inside(start), "the player start is inside the barricade of %s" % spawn.name)
		var path := NavigationServer3D.map_get_path(level.navigation.get_navigation_map(), spawn.global_position, start, true)
		assert_true(path_goes_inside(path, spawn.barricade), "the path of %s goes through its barricade" % spawn.name)


func test_the_compound_navmesh_answers_queries_when_it_loads_right_after_another_level() -> void:
	var first := await spawn_level()
	first.queue_free()
	await physics_frames(1)
	var level := await spawn_level(null, COMPOUND_SCENE)
	var map := level.navigation.get_navigation_map()
	assert_eq(NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO), level.navigation.get_rid(), "the region that owns the navmesh at the origin")


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


func test_the_level_has_an_ammo_station_and_a_weapon_station_near_the_player_start_and_wall_buys() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var player := level.get_node("Player") as Player
	assert_true(sells(level, AmmoItem), "an ammo station")
	assert_true(sells_weapon(level, "SMG"), "a weapon station that sells the SMG")
	assert_true(sells_weapon(level, "SHOTGUN"), "a wall buy that sells the shotgun")
	assert_true(sells_weapon(level, "RIFLE"), "a wall buy that sells the rifle")
	assert_true(sells_weapon(level, "MACHINE GUN"), "a wall buy that sells the machine gun")
	for station: BuyStation in _shops(level).filter(func(station: BuyStation) -> bool: return not station is WallBuy):
		assert_true(station.global_position.distance_to(player.global_position) < 10.0, "%s is in the yard near the start" % station.name)


func test_the_power_switch_is_in_the_office_and_powers_every_machine_outside_it() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var power := level.get_node("PowerSwitch") as PowerSwitch
	assert_true(OFFICE.has_point(Vector2(power.global_position.x, power.global_position.z)), "the switch is in the office")
	var machines: Array[BuyStation] = stations_in(level).filter(_is_machine)
	assert_eq(machines.filter(func(station: BuyStation) -> bool: return station.item is PerkItem).size(), 4, "perk machines")
	assert_eq(machines.filter(func(station: BuyStation) -> bool: return station.item is UpgradeItem).size(), 1, "upgrade machines")
	for machine: BuyStation in machines:
		var at := Vector2(machine.global_position.x, machine.global_position.z)
		assert_true(not WAREHOUSE.has_point(at) and not OFFICE.has_point(at), "%s is outside both buildings" % machine.name)
		assert_true(machine.power == power, "%s needs the switch" % machine.name)
		assert_true(not machine.has_power(), "%s has no power at the start" % machine.name)
	power.turn_on()
	for machine: BuyStation in machines:
		assert_true(machine.has_power(), "%s has power" % machine.name)


func test_the_weapon_box_starts_near_the_player_and_each_of_its_places_has_a_path_to_the_start() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var box := level.get_node("WeaponBox") as WeaponBox
	var start := level.player.global_position
	assert_true(box.global_position.distance_to(start) < 15.0, "the box starts in the yard near the start")
	assert_true(box.places.size() > 1, "the box has more than one place")
	for node: Node in level.get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).open()
	await run_seconds(1.0)
	for place: Node3D in box.places:
		var front := place.global_position + place.global_basis.z * 1.3
		var back := place.global_position - place.global_basis.z * 1.3
		assert_true(_path_reaches(level, front, start) or _path_reaches(level, back, start), "the player can walk to the box at %s" % place.name)


func _shops(level: Level) -> Array[BuyStation]:
	return stations_in(level).filter(func(station: BuyStation) -> bool: return not (station.item is DoorItem or _is_machine(station)))


func _is_machine(station: BuyStation) -> bool:
	return station.item is PerkItem or station.item is UpgradeItem


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
