extends TestCase


func test_walking_zombie_swings_its_legs_both_ways() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var pitches := await sample_range(func() -> float: return zombie.animator.leg_pitch(), 2.0)
	var swing := deg_to_rad(zombie.animator.leg_swing) * 0.5
	assert_true(pitches.y > swing, "leg swings forward, max %s rad" % pitches.y)
	assert_true(pitches.x < -swing, "leg swings back, min %s rad" % pitches.x)


func test_standing_zombie_keeps_its_legs_still() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	await run_seconds(1.0)
	var pitches := await sample_range(func() -> float: return zombie.animator.leg_pitch(), 0.5)
	assert_true(absf(pitches.y) < 0.01 and absf(pitches.x) < 0.01, "legs at rest, %s to %s rad" % [pitches.x, pitches.y])


func test_attacking_zombie_raises_its_arms_then_slams_them_down() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_damage = 0.0
	var pitches := await sample_range(func() -> float: return zombie.animator.arm_pitch(), zombie.attack_interval * 2.0)
	assert_true(pitches.y > deg_to_rad(zombie.animator.wind_up_angle) * 0.7, "arms wind up, max %s rad" % pitches.y)
	assert_true(pitches.x < -deg_to_rad(zombie.animator.slam_angle) * 0.5, "arms slam below rest, min %s rad" % pitches.x)


func test_dying_zombie_falls_on_its_back_and_stays_until_it_sinks() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	await physics_frames(2)
	Health.find_on(zombie).damage(1.0e6)
	var animator := zombie.animator
	await run_seconds(animator.fall_time + animator.bounce_time + 0.1)
	assert_almost_eq(animator.fall_tilt(), deg_to_rad(animator.fall_angle), 0.05, "zombie lies on its back")
	assert_true(zombie.is_inside_tree(), "the body stays while it lies there")


func test_running_zombie_leans_forward_and_a_walker_does_not() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 25.0), 3)
	var walker := spawn_zombie(Vector3(-5.0, 0.0, -28.0), player)
	var runner := spawn_zombie(Vector3(5.0, 0.0, -28.0), player, Zombie.Gait.RUN)
	await run_seconds(0.5)
	var runner_lean := await sample_range(func() -> float: return runner.animator.torso_lean(), 1.5)
	var run_lean := deg_to_rad(runner.animator.run_lean)
	assert_true(runner_lean.y > run_lean * 0.9, "runner leans forward, max %s rad, pose says %s rad" % [runner_lean.y, run_lean])
	assert_true(runner_lean.x > run_lean * 0.5, "runner keeps leaning, min %s rad" % runner_lean.x)
	assert_true(absf(walker.animator.torso_lean()) < 0.01, "walker stays upright, %s rad" % walker.animator.torso_lean())


func test_running_zombie_takes_longer_strides_and_reaches_forward_with_its_arms() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 25.0), 3)
	var walker := spawn_zombie(Vector3(-5.0, 0.0, -28.0), player)
	var runner := spawn_zombie(Vector3(5.0, 0.0, -28.0), player, Zombie.Gait.RUN)
	await run_seconds(0.5)
	var runner_legs := await sample_range(func() -> float: return runner.animator.leg_pitch(), 2.0)
	var walker_legs := await sample_range(func() -> float: return walker.animator.leg_pitch(), 2.0)
	assert_true(runner_legs.y - runner_legs.x > (walker_legs.y - walker_legs.x) * 1.3, "runner leg swing %s rad, walker %s rad" % [runner_legs.y - runner_legs.x, walker_legs.y - walker_legs.x])
	var runner_arms := await sample_range(func() -> float: return runner.animator.arm_pitch(), 1.0)
	assert_true(runner_arms.x > 0.0, "runner arms stay in front of its body, min %s rad" % runner_arms.x)


func test_standing_runner_stands_upright() -> void:
	var runner := spawn_zombie(Vector3.ZERO, null, Zombie.Gait.RUN)
	await run_seconds(1.0)
	assert_true(absf(runner.animator.torso_lean()) < 0.01, "standing runner lean %s rad" % runner.animator.torso_lean())


func test_attacking_runner_raises_its_arms_then_slams_them_down() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var runner := spawn_zombie(Vector3(0.0, 0.0, -1.0), player, Zombie.Gait.RUN)
	runner.attack_damage = 0.0
	var pitches := await sample_range(func() -> float: return runner.animator.arm_pitch(), runner.attack_interval * 2.0)
	assert_true(pitches.y > deg_to_rad(runner.animator.wind_up_angle) * 0.7, "arms wind up, max %s rad" % pitches.y)
	assert_true(pitches.x < -deg_to_rad(runner.animator.slam_angle) * 0.5, "arms slam below rest, min %s rad" % pitches.x)


func test_dying_runner_falls_on_its_back_and_stands_up_straight_first() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var runner := spawn_zombie(Vector3(0.0, 0.0, -20.0), player, Zombie.Gait.RUN)
	await run_seconds(1.0)
	Health.find_on(runner).damage(1.0e6)
	var animator := runner.animator
	await run_seconds(animator.fall_time + animator.bounce_time + 0.1)
	assert_almost_eq(animator.fall_tilt(), deg_to_rad(animator.fall_angle), 0.05, "runner lies on its back")
	assert_true(absf(animator.torso_lean()) < 0.05, "the lean is gone, %s rad" % animator.torso_lean())
