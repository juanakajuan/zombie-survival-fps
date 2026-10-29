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


func _distance_to_navmesh(map: RID, at: Vector3) -> float:
	var closest := NavigationServer3D.map_get_closest_point(map, at)
	return Vector2(closest.x - at.x, closest.z - at.z).length()


func test_the_level_has_a_buy_station_that_sells_ammo() -> void:
	var level := await spawn_level()
	var stations := stations_in(level)
	assert_eq(stations.size(), 1, "one buy station")
	assert_true(stations.size() == 1 and stations[0].item is AmmoItem, "it sells ammo")
