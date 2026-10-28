extends TestCase

const SETTINGS: RoundSettings = preload("res://rounds/round_settings.tres")


func test_each_round_has_more_and_stronger_zombies_than_the_one_before() -> void:
	for n: int in range(1, 10):
		assert_true(SETTINGS.zombie_count(n + 1) > SETTINGS.zombie_count(n), "round %d has more zombies" % (n + 1))
		assert_true(SETTINGS.zombie_health(n + 1) > SETTINGS.zombie_health(n), "round %d zombies have more health" % (n + 1))
		assert_true(SETTINGS.zombie_speed(n + 1) >= SETTINGS.zombie_speed(n), "round %d zombies are not slower" % (n + 1))
	assert_true(SETTINGS.zombie_speed(2) > SETTINGS.zombie_speed(1), "round 2 zombies are faster")


func test_round_one_zombies_match_the_zombie_defaults() -> void:
	var zombie := (preload("res://zombie/zombie.tscn") as PackedScene).instantiate() as Zombie
	assert_almost_eq(SETTINGS.zombie_speed(1), zombie.move_speed, 0.001, "round 1 speed")
	assert_almost_eq(SETTINGS.zombie_health(1), Health.find_on(zombie).max_health, 0.001, "round 1 health")
	zombie.free()


func test_zombie_speed_stops_at_the_max_speed() -> void:
	assert_almost_eq(SETTINGS.zombie_speed(1000), SETTINGS.max_speed, 0.001, "speed in round 1000")
