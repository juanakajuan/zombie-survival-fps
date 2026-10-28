extends TestCase

const ZOMBIE_SCENE: PackedScene = preload("res://zombie/zombie.tscn")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")
const FRAME_MARGIN := 3

var _region: NavigationRegion3D


func test_zombie_walks_toward_a_still_player() -> void:
	await _build_world()
	var player := await _spawn_player(Vector3(0.0, 0.0, 0.0))
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var start := _flat_distance(zombie, player)
	await _run_seconds(2.0)
	var closed := start - _flat_distance(zombie, player)
	assert_true(closed >= zombie.move_speed * 1.0, "zombie closed %s m in 2 s, speed is %s m/s" % [closed, zombie.move_speed])


func test_zombie_finds_the_player_through_the_player_group() -> void:
	await _build_world()
	var player := await _spawn_player(Vector3(0.0, 0.0, 0.0))
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, -10.0), null)
	var start := _flat_distance(zombie, player)
	await _run_seconds(1.5)
	assert_true(_flat_distance(zombie, player) < start - zombie.move_speed * 0.5, "zombie without a set target still approaches")


func test_zombie_goes_around_a_wall_to_reach_the_player() -> void:
	await _build_world(true)
	var player := await _spawn_player(Vector3(0.0, 0.0, 6.0))
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_damage = 0.0
	var reach := zombie.attack_range + Zombie.ATTACK_EXIT_MARGIN
	for _i: int in 15:
		await _run_seconds(1.0)
		if _flat_distance(zombie, player) <= reach:
			break
	assert_true(_flat_distance(zombie, player) <= reach, "zombie reached the player, distance %s" % _flat_distance(zombie, player))


func test_zombie_in_range_hits_once_per_interval_and_not_before_the_first() -> void:
	await _build_world()
	var player := await _spawn_player(Vector3(0.0, 0.0, 0.0))
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_interval = 0.5
	var health := Health.find_on(player)
	await _run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health, 0.001, "no hit before the first interval")
	await _run_seconds(zombie.attack_interval * 0.5 + FRAME_MARGIN / 60.0)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "one hit after the first interval")
	await _run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "still one hit half an interval later")
	await _run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - 2.0 * zombie.attack_damage, 0.001, "two hits after two intervals")


func test_zombie_out_of_range_does_no_damage() -> void:
	await _build_world()
	var player := await _spawn_player(Vector3(0.0, 0.0, 0.0))
	var zombie := _spawn_zombie(Vector3.ZERO, player)
	zombie.position.z = -(zombie.attack_range + 2.0)
	zombie.move_speed = 0.0
	zombie.attack_interval = 0.3
	await _run_seconds(zombie.attack_interval * 3.0)
	var health := Health.find_on(player)
	assert_almost_eq(health.current, health.max_health, 0.001, "player is unharmed")


func test_enough_pistol_shots_kill_the_zombie_and_remove_it() -> void:
	await _build_world()
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var shots := ceili(Health.find_on(zombie).max_health / PISTOL.damage)
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await _run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	await physics_frames(2)
	assert_true(not is_instance_valid(zombie) or not zombie.is_inside_tree(), "zombie left the tree")


func test_fewer_pistol_shots_leave_the_zombie_alive() -> void:
	await _build_world()
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var health := Health.find_on(zombie)
	var shots := ceili(health.max_health / PISTOL.damage) - 1
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await _run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	assert_true(zombie.is_inside_tree(), "zombie still in the tree")
	assert_almost_eq(health.current, health.max_health - shots * PISTOL.damage, 0.001, "zombie lost damage per shot")


func test_zombie_ignores_a_dead_player() -> void:
	await _build_world()
	var player := await _spawn_player(Vector3(0.0, 0.0, 0.0))
	Health.find_on(player).damage(1000000.0)
	var zombie := _spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_interval = 0.3
	var start := zombie.global_position
	await _run_seconds(1.5)
	assert_almost_eq(zombie.global_position.distance_to(start), 0.0, 0.05, "zombie stays where it is")


func _build_world(with_wall: bool = false) -> void:
	_region = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.agent_radius = 0.5
	mesh.agent_max_climb = 0.25
	mesh.agent_height = 2.0
	_region.navigation_mesh = mesh
	_region.add_child(_box(Vector3(60.0, 1.0, 60.0), Vector3(0.0, -0.5, 0.0)))
	if with_wall:
		_region.add_child(_box(Vector3(10.0, 2.0, 0.5), Vector3(0.0, 1.0, 0.0)))
	add_child(_region)
	_region.bake_navigation_mesh(false)
	# The navigation server needs several physics frames before it can answer path queries from the new mesh.
	for _i: int in 60:
		await physics_frames(1)
		if not NavigationServer3D.map_get_path(_region.get_navigation_map(), Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, -4.0), true).is_empty():
			return
	failures.append("navigation map never became ready")


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = at
	body.add_child(shape)
	return body


func _spawn_player(at: Vector3) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	add_child(player)
	await physics_frames(3)
	return player


func _spawn_zombie(at: Vector3, target: Node3D) -> Zombie:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	zombie.position = at
	zombie.target = target
	add_child(zombie)
	return zombie


func _spawn_weapon(at: Vector3) -> Weapon:
	var weapon := WEAPON_SCENE.instantiate() as Weapon
	weapon.data = PISTOL
	weapon.position = at
	add_child(weapon)
	return weapon


func _flat_distance(a: Node3D, b: Node3D) -> float:
	var offset := a.global_position - b.global_position
	offset.y = 0.0
	return offset.length()


func _run_seconds(seconds: float) -> void:
	await physics_frames(roundi(seconds * Engine.physics_ticks_per_second))
