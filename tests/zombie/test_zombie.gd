extends TestCase

const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")
const FRAME_MARGIN := 3


func test_zombie_walks_toward_a_still_player() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var start := _flat_distance(zombie, player)
	await run_seconds(2.0)
	var closed := start - _flat_distance(zombie, player)
	assert_true(closed >= zombie.move_speed * 1.0, "zombie closed %s m in 2 s, speed is %s m/s" % [closed, zombie.move_speed])


func test_zombie_finds_the_player_through_the_player_group() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), null)
	var start := _flat_distance(zombie, player)
	await run_seconds(1.5)
	assert_true(_flat_distance(zombie, player) < start - zombie.move_speed * 0.5, "zombie without a set target still approaches")


func test_zombie_goes_around_a_wall_to_reach_the_player() -> void:
	await spawn_nav_world(true)
	var player := await spawn_player(Vector3(0.0, 0.0, 6.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_damage = 0.0
	var reach := zombie.attack_range + zombie.attack_exit_margin
	for _i: int in 15:
		await run_seconds(1.0)
		if _flat_distance(zombie, player) <= reach:
			break
	assert_true(_flat_distance(zombie, player) <= reach, "zombie reached the player, distance %s" % _flat_distance(zombie, player))


func test_zombie_in_range_hits_once_per_interval_and_not_before_the_first() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_interval = 0.5
	var health := Health.find_on(player)
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health, 0.001, "no hit before the first interval")
	await run_seconds(zombie.attack_interval * 0.5 + FRAME_MARGIN / 60.0)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "one hit after the first interval")
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "still one hit half an interval later")
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - 2.0 * zombie.attack_damage, 0.001, "two hits after two intervals")


func test_zombie_out_of_range_does_no_damage() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3.ZERO, player)
	zombie.position.z = -(zombie.attack_range + 2.0)
	zombie.move_speed = 0.0
	zombie.attack_interval = 0.3
	await run_seconds(zombie.attack_interval * 3.0)
	var health := Health.find_on(player)
	assert_almost_eq(health.current, health.max_health, 0.001, "player is unharmed")


func test_enough_pistol_shots_kill_the_zombie_and_remove_it() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var shots := ceili(Health.find_on(zombie).max_health / PISTOL.damage)
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	await physics_frames(2)
	assert_true(zombie.is_dead(), "zombie is dead")
	await run_seconds(zombie.animator.death_length() + FRAME_MARGIN / 60.0)
	assert_true(not is_instance_valid(zombie) or not zombie.is_inside_tree(), "zombie left the tree after its death animation")


func test_fewer_pistol_shots_leave_the_zombie_alive() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var health := Health.find_on(zombie)
	var shots := ceili(health.max_health / PISTOL.damage) - 1
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	assert_true(zombie.is_inside_tree(), "zombie still in the tree")
	assert_almost_eq(health.current, health.max_health - shots * PISTOL.damage, 0.001, "zombie lost damage per shot")


func test_zombie_ignores_a_dead_player() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	Health.find_on(player).damage(1000000.0)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_interval = 0.3
	var start := zombie.global_position
	await run_seconds(1.5)
	assert_almost_eq(zombie.global_position.distance_to(start), 0.0, 0.05, "zombie stays where it is")


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
