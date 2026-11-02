extends TestCase


func test_every_layer_1_static_body_is_off_the_navmesh() -> void:
	var level := await spawn_level()
	var map := level.navigation.get_navigation_map()
	var agent_radius := level.navigation.navigation_mesh.agent_radius
	var player_start := level.get_node("Player") as Player
	assert_true(_distance_to_navmesh(map, player_start.global_position) < agent_radius, "the player start is on the navmesh")
	var bodies := level.find_children("*", "StaticBody3D", true, false)
	assert_true(not bodies.is_empty(), "the level has static bodies")
	for node: Node in bodies:
		var body := node as StaticBody3D
		if body.collision_layer & 1 == 0:
			continue
		var distance := _distance_to_navmesh(map, body.global_position)
		assert_true(distance >= agent_radius, "%s: the navmesh is %.2f m from this layer-1 static body, so zombies walk through it" % [body.name, distance])


func test_round_1_starts_and_the_level_runs_for_5_seconds() -> void:
	var level := await spawn_level()
	assert_eq((level.get_node("RoundManager") as RoundManager).round_number, 1, "round number")
	await run_seconds(5.0)


func test_the_yard_spawn_point_has_a_path_to_the_player_start_through_its_window() -> void:
	var level := await spawn_level()
	var start := level.player.global_position
	var with_barricade: Array[SpawnPoint] = spawn_points_in(level).filter(func(point: SpawnPoint) -> bool: return point.barricade != null)
	assert_eq(with_barricade.size(), 1, "spawn points that name a barricade")
	for spawn: SpawnPoint in with_barricade:
		var path := NavigationServer3D.map_get_path(level.navigation.get_navigation_map(), spawn.global_position, start, true)
		assert_true(not path.is_empty() and path[path.size() - 1].distance_to(start) < 1.0, "%s has no path to the player start" % spawn.name)
		assert_true(not spawn.barricade.is_inside(spawn.global_position), "%s is outside its barricade" % spawn.name)
		assert_true(path_goes_inside(path, spawn.barricade), "the path of %s goes through its barricade" % spawn.name)


func test_a_zombie_where_the_routes_around_the_far_dummy_cost_the_same_walks_on_toward_the_player_start() -> void:
	var settings := ROUND_SETTINGS.duplicate() as RoundSettings
	settings.early_round_counts = PackedInt32Array([0])
	var level := await spawn_level(settings)
	# The point where a round 1 zombie of SpawnNorthEast stopped (issue 125). A step west of it makes the east route
	# shorter, and a step east makes the west route shorter.
	var zombie := spawn_zombie(Vector3(2.43, 0.0, -12.68), level.player)
	var start := _flat_distance(zombie, level.player)
	await run_seconds(2.0)
	var closed := start - _flat_distance(zombie, level.player)
	assert_true(closed >= zombie.move_speed * 1.0, "zombie closed %.2f m in 2 s, speed is %s m/s" % [closed, zombie.move_speed])


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()

func _distance_to_navmesh(map: RID, at: Vector3) -> float:
	var closest := NavigationServer3D.map_get_closest_point(map, at)
	return Vector2(closest.x - at.x, closest.z - at.z).length()


func test_the_level_has_an_ammo_station_and_a_weapon_station_that_sells_the_smg() -> void:
	var level := await spawn_level()
	assert_true(sells(level, AmmoItem), "an ammo station")
	assert_true(sells_weapon(level, "SMG"), "a weapon station that sells the SMG")


func test_the_level_has_an_upgrade_machine_on_the_power_switch() -> void:
	var level := await spawn_level()
	var machines: Array[BuyStation] = stations_in(level).filter(func(station: BuyStation) -> bool: return station.item is UpgradeItem)
	assert_eq(machines.size(), 1, "one upgrade machine")
	assert_true(machines[0].power == level.get_node("PowerSwitch"), "it needs the power switch")
