extends TestCase


func arena_shape_problems(arena: Arena) -> PackedStringArray:
	var problems: PackedStringArray = []
	for node: Node in arena.find_children("*", "StaticBody3D"):
		var body: StaticBody3D = node as StaticBody3D
		var shape: BoxShape3D = (body.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D
		var mesh: BoxMesh = (body.get_node(^"Mesh") as MeshInstance3D).mesh as BoxMesh
		if body.collision_layer != Layers.WORLD or shape.size != mesh.size:
			problems.append(str(arena.get_path_to(body)))
	return problems


func test_arena_navigation() -> void:
	var arena: Arena = await make_arena()
	ok(arena.navigation.navigation_mesh.get_polygon_count() > 0 and arena.spawns().size() == 8, "The arena bakes a navigation mesh and has 8 zombie spawn points")
	ok(arena.stations.size() == 13 and arena.box != null and arena.box in arena.stations, "The arena has three wall buys, the box, four perk machines, the upgrade machine, two doors, the power switch, and the cache")
	ok(arena_shape_problems(arena).is_empty(), "Each static body in the arena scene is on Layers.WORLD, and its collision box is the size of its mesh box: %s" % ", ".join(arena_shape_problems(arena)))
	var nav_mesh: NavigationMesh = arena.navigation.navigation_mesh
	ok(is_equal_approx(nav_mesh.agent_height, Zombie.HEIGHT) and nav_mesh.geometry_collision_mask == Layers.WORLD and is_equal_approx(nav_mesh.cell_height, NavigationServer3D.map_get_cell_height(arena.get_world_3d().navigation_map)), "The navigation mesh uses the zombie height, the world layer, and the cell height of the navigation map")
	var crate_shape: BoxShape3D = (arena.box.get_parent().get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D
	ok(crate_shape.size == MysteryBox.CRATE_SIZE, "The box crate in the arena scene is MysteryBox.CRATE_SIZE")
	var map: RID = arena.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(-10.0, 0.0, -3.0), Vector3(-10.0, 1.5, -10.0), true)
	var via_ramp: bool = false
	for point: Vector3 in path:
		via_ramp = via_ramp or point.x > -6.5
	ok(path.size() > 0 and absf(path[path.size() - 1].y - 1.5) < 0.3 and via_ramp, "A path from the foot of the stairs to the platform top goes around by the ramp")
	var near_box: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(10.0, 0.0, 19.5))
	measure("distance from the box center to the walkable mesh", Vector2(near_box.x - 10.0, near_box.z - 19.5).length(), "m")
	ok(Vector2(near_box.x - 10.0, near_box.z - 19.5).length() >= 0.9, "The bake cuts the box crate out, so the walkable mesh is 0.9 m or more from its center")
	await finish(arena)


func test_zombie() -> void:
	var arena: Arena = await make_arena()
	var player: Player = spawn(arena, tuning(), Vector3(8.0, 0.0, 7.0), 0.0)
	var zombie: Zombie = make_zombie(arena, Vector3(8.0, 0.0, 1.0), 150.0, 3.2, player)
	var attacks: Array[float] = []
	var deaths: Array[bool] = []
	zombie.attacked.connect(func(damage: float) -> void: attacks.append(damage))
	zombie.died.connect(func(headshot: bool) -> void: deaths.append(headshot))
	var reached: int = -1
	for tick: int in range(1, 601):
		await tree.physics_frame
		if zombie.state == Zombie.State.ATTACK:
			reached = tick
			break
	measure("time for a 3.2 m/s zombie to reach the player around a 2 m block", reached * TICK, "s")
	var offset: Vector3 = player.global_position - zombie.global_position
	ok(reached > 0 and reached * TICK < 6.0 and Vector2(offset.x, offset.z).length() <= 1.3, "A zombie behind a 2 m block reaches attack range of the player within 6 s")
	await ticks(150)
	ok(attacks == [40.0, 40.0, 40.0], "In 2.5 s of ATTACK the zombie attacks three times for 40, 1.2 s apart")
	player.teleport(Vector3(-5.0, 0.0, 15.0), 0.0)
	await ticks(2)
	ok(zombie.state == Zombie.State.CHASE, "The zombie goes back to CHASE when the player leaves range")
	zombie.take_damage(100.0, false)
	ok(zombie.state == Zombie.State.CHASE and zombie.health == 50.0 and deaths.is_empty(), "100 damage leaves 50 health and the zombie keeps chasing")
	zombie.take_damage(70.0, true)
	zombie.take_damage(70.0, true)
	ok(zombie.state == Zombie.State.DEAD and zombie.health == 0.0 and deaths == [true], "A 70 headshot at 50 health kills the zombie once and reports a headshot")
	await ticks(30)
	ok(is_instance_valid(zombie), "The dead zombie still sinks 0.5 s after death")
	await ticks(40)
	ok(not is_instance_valid(zombie), "The dead zombie frees itself 1.0 s after death")
	await finish(arena)


func test_zones() -> void:
	var arena: Arena = await make_arena()
	ok(arena.spawns().size() == 8 and arena.open_zones == [&"yard"], "At first only the 8 Yard spawn points are open")
	arena.open_zone(&"warehouse")
	arena.open_zone(&"warehouse")
	ok(arena.spawns().size() == 11 and arena.open_zones == [&"yard", &"warehouse"], "open_zone adds the 3 Warehouse spawn points one time")
	var farthest: float = 0.0
	for spawn_point: Vector3 in arena.zone_spawns[&"warehouse"]:
		farthest = maxf(farthest, spawn_point.distance_to(Vector3(0.0, 0.0, 6.0)))
	ok(farthest > 12.0, "The Warehouse spawn points are far from the player spawn")
	var map: RID = arena.get_world_3d().navigation_map
	for zone: StringName in arena.zone_spawns:
		for spawn_point: Vector3 in arena.zone_spawns[zone]:
			var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, spawn_point)
			ok(Vector2(snapped.x - spawn_point.x, snapped.z - spawn_point.z).length() < 0.5 and not NavigationServer3D.map_get_path(map, arena.player_spawn.origin, spawn_point, true).is_empty(), "The %s spawn point %s is on the navigation mesh and has a path from the player spawn" % [zone, spawn_point])
	var doors: Array[Door] = []
	for station: Station in arena.stations:
		if station is Door:
			doors.append(station as Door)
	var zones: Array[StringName] = []
	for door: Door in doors:
		zones.append(door.zone)
	zones.sort()
	var keys: Array[StringName] = []
	for zone: StringName in arena.zone_spawns:
		if zone != Arena.START_ZONE:
			keys.append(zone)
	keys.sort()
	ok(zones == keys, "Each zone except the Yard has exactly one door")
	await finish(arena)
