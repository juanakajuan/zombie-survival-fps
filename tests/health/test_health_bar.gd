extends TestCase


func test_bar_is_hidden_until_the_first_hit() -> void:
	var zombie := spawn_zombie(Vector3.ZERO)
	await physics_frames(1)
	assert_true(not zombie.health_bar.visible, "an unhurt zombie has no bar")
	var health := Health.find_on(zombie)
	health.damage(health.max_health * 0.4)
	assert_true(zombie.health_bar.visible, "a hurt zombie shows its bar")
	assert_almost_eq(zombie.health_bar.fill(), 0.6, 0.001, "the bar shows the health that is left")


func test_bar_hides_when_the_zombie_dies() -> void:
	var zombie := spawn_zombie(Vector3.ZERO)
	await physics_frames(1)
	var health := Health.find_on(zombie)
	health.damage(health.max_health * 0.5)
	health.damage(health.max_health)
	assert_true(not zombie.health_bar.visible, "a dead zombie has no bar")
	assert_almost_eq(zombie.health_bar.fill(), 0.0, 0.001, "the bar is empty")
