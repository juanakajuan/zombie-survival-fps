extends TestCase

const SETTLE_FRAMES := 3
const CHASE_SECONDS := 2.0


func test_chases_nearer_player() -> void:
	await spawn_nav_world()
	var near := await spawn_player(Vector3(6.0, 0.0, 0.0), SETTLE_FRAMES)
	var far := await spawn_player(Vector3(-14.0, 0.0, 0.0), SETTLE_FRAMES)
	var zombie := spawn_zombie_chasing(Vector3.ZERO, _targets(far, near))
	var near_start := _flat_distance(zombie, near)
	var far_start := _flat_distance(zombie, far)
	await run_seconds(CHASE_SECONDS)
	assert_true(near_start - _flat_distance(zombie, near) >= zombie.move_speed, "the zombie closes in on the nearer player")
	assert_true(_flat_distance(zombie, far) > far_start, "the zombie moves away from the farther player")


func test_switches_when_nearer_player_dies() -> void:
	await spawn_nav_world()
	var near := await spawn_player(Vector3(0.0, 0.0, -5.0), SETTLE_FRAMES)
	var far := await spawn_player(Vector3(0.0, 0.0, 10.0), SETTLE_FRAMES)
	var zombie := spawn_zombie_chasing(Vector3.ZERO, _targets(near, far))
	var near_start := _flat_distance(zombie, near)
	await run_seconds(0.5)
	assert_true(_flat_distance(zombie, near) < near_start, "the zombie first walks toward the nearer player")
	var health := Health.find_on(near)
	health.damage(health.max_health)
	var far_at_death := _flat_distance(zombie, far)
	await run_seconds(CHASE_SECONDS)
	assert_true(near.is_dead(), "the nearer player is dead")
	assert_true(far_at_death - _flat_distance(zombie, far) >= zombie.move_speed, "the zombie turns to the living player")


func test_chases_downed_player() -> void:
	await spawn_nav_world()
	var near := await spawn_player(Vector3(0.0, 0.0, -5.0), SETTLE_FRAMES)
	var far := await spawn_player(Vector3(0.0, 0.0, 10.0), SETTLE_FRAMES)
	down_player(near)
	var zombie := spawn_zombie_chasing(Vector3.ZERO, _targets(near, far))
	var near_start := _flat_distance(zombie, near)
	await run_seconds(CHASE_SECONDS)
	assert_true(near.is_downed(), "the nearer player is downed")
	assert_true(near_start - _flat_distance(zombie, near) >= zombie.move_speed, "the zombie still closes in on the downed player")


func test_late_player_becomes_target() -> void:
	var level := await spawn_level()
	var manager := level.round_manager
	var zombie: Zombie = null
	for child: Node in manager.get_children():
		if child is Zombie:
			zombie = child as Zombie
			break
	assert_true(zombie != null, "round 1 spawned a zombie")
	if zombie == null:
		return
	var late := add_player_to(level, zombie.global_position + Vector3(1.0, 0.0, 0.0))
	await run_seconds(CHASE_SECONDS)
	var late_health := Health.find_on(late)
	assert_true(late_health.current < late_health.max_health, "the zombie attacks the player that joined late")
	var first_health := Health.find_on(level.players[0])
	assert_eq(first_health.current, first_health.max_health, "the first player is unharmed")


func _targets(first: Node3D, second: Node3D) -> Array[Node3D]:
	return [first, second]


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
