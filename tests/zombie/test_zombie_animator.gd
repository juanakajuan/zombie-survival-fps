extends TestCase


func test_walking_zombie_swings_its_legs_both_ways() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var pitches := await _pitch_range(func() -> float: return zombie.animator.leg_pitch(), 2.0)
	var swing := deg_to_rad(zombie.animator.leg_swing) * 0.5
	assert_true(pitches.y > swing, "leg swings forward, max %s rad" % pitches.y)
	assert_true(pitches.x < -swing, "leg swings back, min %s rad" % pitches.x)


func test_standing_zombie_keeps_its_legs_still() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	await run_seconds(1.0)
	var pitches := await _pitch_range(func() -> float: return zombie.animator.leg_pitch(), 0.5)
	assert_true(absf(pitches.y) < 0.01 and absf(pitches.x) < 0.01, "legs at rest, %s to %s rad" % [pitches.x, pitches.y])


func test_attacking_zombie_raises_its_arms_then_slams_them_down() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_damage = 0.0
	var pitches := await _pitch_range(func() -> float: return zombie.animator.arm_pitch(), zombie.attack_interval * 2.0)
	assert_true(pitches.y > deg_to_rad(zombie.animator.wind_up_angle) * 0.7, "arms wind up, max %s rad" % pitches.y)
	assert_true(pitches.x < -deg_to_rad(zombie.animator.slam_angle) * 0.5, "arms slam below rest, min %s rad" % pitches.x)


## The lowest (x) and highest (y) value that `value` gives over `seconds` of physics frames.
func _pitch_range(value: Callable, seconds: float) -> Vector2:
	var lowest := INF
	var highest := -INF
	for _i: int in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frames(1)
		var sample: float = value.call()
		lowest = minf(lowest, sample)
		highest = maxf(highest, sample)
	return Vector2(lowest, highest)


func test_dying_zombie_falls_on_its_back_and_stays_until_it_sinks() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	await physics_frames(2)
	Health.find_on(zombie).damage(1.0e6)
	var animator := zombie.animator
	await run_seconds(animator.fall_time + animator.bounce_time + 0.1)
	assert_almost_eq(animator.fall_tilt(), deg_to_rad(animator.fall_angle), 0.05, "zombie lies on its back")
	assert_true(zombie.is_inside_tree(), "the body stays while it lies there")
