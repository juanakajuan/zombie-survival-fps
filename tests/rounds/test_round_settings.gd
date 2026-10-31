extends TestCase

const SETTINGS: RoundSettings = preload("res://rounds/round_settings.tres")


func test_each_round_has_more_and_stronger_zombies_than_the_one_before() -> void:
	for n: int in range(1, 10):
		assert_true(SETTINGS.zombie_count(n + 1) > SETTINGS.zombie_count(n), "round %d has more zombies" % (n + 1))
		assert_true(SETTINGS.zombie_health(n + 1) > SETTINGS.zombie_health(n), "round %d zombies have more health" % (n + 1))
		assert_true(SETTINGS.zombie_speed(n + 1) >= SETTINGS.zombie_speed(n), "round %d zombies are not slower" % (n + 1))
	assert_true(SETTINGS.zombie_speed(2) > SETTINGS.zombie_speed(1), "round 2 zombies are faster")


func test_the_game_settings_set_how_fast_and_tough_round_one_zombies_are() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var manager := RoundManager.new()
	manager.settings = SETTINGS
	manager.player = player
	var marker := SpawnPoint.new()
	marker.position = Vector3(0.0, 0.0, -10.0)
	manager.add_child(marker)
	add_child(manager)
	await physics_frames(2)
	var zombie := manager.get_child(1) as Zombie
	var start := _flat_distance(zombie, player)
	var measure_time := SETTINGS.spawn_interval * 0.9
	await run_seconds(measure_time)
	var speed := (start - _flat_distance(zombie, player)) / measure_time
	assert_true(speed > SETTINGS.zombie_speed(1) * 0.8 and speed < SETTINGS.zombie_speed(1) * 1.05,
		"round 1 zombie walks at %s m/s, settings say %s m/s" % [speed, SETTINGS.zombie_speed(1)])
	var health := Health.find_on(zombie)
	health.damage(SETTINGS.zombie_health(1) - 1.0)
	assert_true(not health.is_dead(), "round 1 zombie lives through its settings health minus 1")
	health.damage(1.0)
	assert_true(health.is_dead(), "round 1 zombie dies at its settings health")


func test_zombie_speed_stops_at_the_max_speed() -> void:
	assert_almost_eq(SETTINGS.zombie_speed(1000), SETTINGS.max_speed, 0.001, "speed in round 1000")


func test_runners_start_at_the_first_runner_round() -> void:
	assert_eq(SETTINGS.runner_count(SETTINGS.first_runner_round - 1), 0, "runners the round before")
	assert_true(SETTINGS.runner_count(SETTINGS.first_runner_round) > 0, "runners in the first runner round")


func test_runner_count_grows_with_the_round_and_stops_at_the_max_fraction() -> void:
	var settings := RoundSettings.new()
	settings.first_runner_round = 3
	settings.first_runner_fraction = 0.25
	settings.runner_fraction_per_round = 0.25
	settings.max_runner_fraction = 0.5
	var count := settings.zombie_count(3)
	assert_eq(settings.runner_count(2), 0, "runners in round 2")
	assert_eq(settings.runner_count(3), roundi(count * 0.25), "runners in round 3")
	assert_eq(settings.runner_count(4), roundi(settings.zombie_count(4) * 0.5), "runners in round 4")
	assert_eq(settings.runner_count(100), roundi(settings.zombie_count(100) * 0.5), "runners in round 100")


func test_runner_count_is_never_more_than_the_zombie_count() -> void:
	var settings := RoundSettings.new()
	settings.first_runner_round = 1
	settings.first_runner_fraction = 1.0
	settings.max_runner_fraction = 1.0
	for n: int in range(1, 20):
		assert_true(settings.runner_count(n) <= settings.zombie_count(n), "round %d has at most all zombies as runners" % n)
	assert_eq(settings.runner_count(1), settings.zombie_count(1), "all zombies run at fraction 1")


func test_runners_are_faster_than_the_fastest_walker() -> void:
	assert_true(SETTINGS.runner_speed > SETTINGS.max_speed, "runner speed %s, max walking speed %s" % [SETTINGS.runner_speed, SETTINGS.max_speed])


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
