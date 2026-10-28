extends TestCase

const SPAWN_POINTS: Array[Vector3] = [Vector3(-4.0, 0.0, -4.0), Vector3(4.0, 0.0, -4.0), Vector3(0.0, 0.0, 4.0)]
const FRAME_MARGIN := 3

var _started: Array[int] = []
var _ended: Array[int] = []


func test_round_one_starts_when_the_manager_loads() -> void:
	var manager := _spawn_manager(_settings())
	await physics_frames(1)
	assert_eq(manager.round_number, 1, "round number")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "state")
	assert_eq(_started, [1] as Array[int], "round_started signals")


func test_round_spawns_the_settings_count_at_the_spawn_points() -> void:
	var settings := _settings()
	# One zombie per point, because zombies that spawn on the same point push each other away from it.
	settings.first_round_zombies = SPAWN_POINTS.size()
	var manager := _spawn_manager(settings)
	await _run_seconds(settings.spawn_interval * settings.zombie_count(1) + 1.0)
	var zombies := _zombies(manager)
	assert_eq(zombies.size(), settings.zombie_count(1), "zombie count in round 1")
	var used: Array[Vector3] = []
	for zombie: Zombie in zombies:
		var spot := _nearest_spawn_point(zombie)
		assert_true(_flat_distance(zombie.global_position, spot) < 0.01, "zombie at %s is at a spawn point" % zombie.global_position)
		if spot not in used:
			used.append(spot)
	assert_eq(used.size(), SPAWN_POINTS.size(), "spawn points used")


func test_break_starts_when_the_last_zombie_dies_and_the_next_round_after_it() -> void:
	var settings := _settings()
	var manager := _spawn_manager(settings)
	await _spawn_all(manager, settings)
	var zombies := _zombies(manager)
	for i: int in zombies.size() - 1:
		Health.find_on(zombies[i]).damage(1.0e6)
	await physics_frames(2)
	assert_eq(manager.state, RoundManager.State.ACTIVE, "state with one zombie left")
	assert_eq(_ended, [] as Array[int], "round_ended signals with one zombie left")
	Health.find_on(zombies[-1]).damage(1.0e6)
	await physics_frames(2)
	assert_eq(manager.state, RoundManager.State.BREAK, "state after the last zombie")
	assert_eq(_ended, [1] as Array[int], "round_ended signals")
	assert_eq(_zombies(manager).size(), 0, "zombies during the break")
	await _run_seconds(settings.break_time * 0.5)
	assert_eq(manager.round_number, 1, "round number during the break")
	assert_eq(_started, [1] as Array[int], "round_started signals during the break")
	await _run_seconds(settings.break_time * 0.5 + FRAME_MARGIN / 60.0)
	assert_eq(manager.round_number, 2, "round number after the break")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "state after the break")
	assert_eq(_started, [1, 2] as Array[int], "round_started signals after the break")


func test_round_does_not_end_while_zombies_wait_to_spawn() -> void:
	var settings := _settings()
	settings.spawn_interval = 1.0
	var manager := _spawn_manager(settings)
	await physics_frames(2)
	var zombies := _zombies(manager)
	assert_eq(zombies.size(), 1, "zombies right after the start")
	Health.find_on(zombies[0]).damage(1.0e6)
	await physics_frames(2)
	assert_eq(manager.state, RoundManager.State.ACTIVE, "state")
	assert_eq(_ended, [] as Array[int], "round_ended signals")


func test_next_round_has_more_zombies_with_more_health_and_speed() -> void:
	var settings := _settings()
	var manager := _spawn_manager(settings)
	await _spawn_all(manager, settings)
	var first := _zombies(manager)[0]
	var first_health := Health.find_on(first).max_health
	var first_speed := first.move_speed
	assert_almost_eq(first_health, settings.zombie_health(1), 0.001, "round 1 health")
	assert_almost_eq(first_speed, settings.zombie_speed(1), 0.001, "round 1 speed")
	for zombie: Zombie in _zombies(manager):
		Health.find_on(zombie).damage(1.0e6)
	await _run_seconds(settings.break_time + FRAME_MARGIN / 60.0)
	await _spawn_all(manager, settings)
	var zombies := _zombies(manager)
	assert_eq(zombies.size(), settings.zombie_count(2), "zombie count in round 2")
	for zombie: Zombie in zombies:
		assert_almost_eq(Health.find_on(zombie).max_health, settings.zombie_health(2), 0.001, "round 2 health")
		assert_almost_eq(Health.find_on(zombie).current, settings.zombie_health(2), 0.001, "round 2 zombie starts at full health")
		assert_almost_eq(zombie.move_speed, settings.zombie_speed(2), 0.001, "round 2 speed")
	assert_true(Health.find_on(zombies[0]).max_health > first_health, "round 2 zombies have more health")
	assert_true(zombies[0].move_speed > first_speed, "round 2 zombies are faster")


func _settings() -> RoundSettings:
	var settings := RoundSettings.new()
	settings.first_round_zombies = 3
	settings.zombies_per_round = 2
	settings.first_round_health = 50.0
	settings.health_per_round = 25.0
	settings.first_round_speed = 0.0
	settings.speed_per_round = 0.5
	settings.max_speed = 5.0
	settings.break_time = 0.5
	settings.spawn_interval = 0.1
	return settings


func _spawn_manager(settings: RoundSettings) -> RoundManager:
	add_child(_floor())
	var manager := RoundManager.new()
	manager.settings = settings
	for at: Vector3 in SPAWN_POINTS:
		var marker := Marker3D.new()
		marker.position = at
		manager.add_child(marker)
	manager.round_started.connect(func(n: int) -> void: _started.append(n))
	manager.round_ended.connect(func(n: int) -> void: _ended.append(n))
	add_child(manager)
	return manager


func _floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 30.0)
	shape.shape = box
	body.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	return body


func _spawn_all(manager: RoundManager, settings: RoundSettings) -> void:
	await _run_seconds(settings.spawn_interval * settings.zombie_count(manager.round_number) + 0.2)


func _zombies(manager: RoundManager) -> Array[Zombie]:
	var zombies: Array[Zombie] = []
	for child: Node in manager.get_children():
		if child is Zombie and not child.is_queued_for_deletion():
			zombies.append(child as Zombie)
	return zombies


func _nearest_spawn_point(zombie: Zombie) -> Vector3:
	var best := SPAWN_POINTS[0]
	for at: Vector3 in SPAWN_POINTS:
		if _flat_distance(zombie.global_position, at) < _flat_distance(zombie.global_position, best):
			best = at
	return best


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run_seconds(seconds: float) -> void:
	await physics_frames(roundi(seconds * Engine.physics_ticks_per_second))
