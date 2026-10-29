extends TestCase

const SETTLE_FRAMES := 3


func test_walking_player_swings_its_legs_both_ways() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	var pitches := await sample_range(func() -> float: return player.animator.leg_pitch(), 2.0)
	var swing := deg_to_rad(player.animator.leg_swing) * 0.5
	assert_true(pitches.y > swing, "leg swings forward, max %s rad" % pitches.y)
	assert_true(pitches.x < -swing, "leg swings back, min %s rad" % pitches.x)


func test_standing_player_keeps_its_legs_still() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await run_seconds(0.5)
	var pitches := await sample_range(func() -> float: return player.animator.leg_pitch(), 0.5)
	assert_true(absf(pitches.y) < 0.01 and absf(pitches.x) < 0.01, "legs at rest, %s to %s rad" % [pitches.x, pitches.y])


func test_jumping_player_holds_a_stride_in_the_air() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("jump")
	await run_seconds(0.25)
	assert_true(not player.is_on_floor(), "player is in the air")
	assert_true(player.animator.leg_pitch() > deg_to_rad(player.animator.front_leg) * 0.7,
		"front leg is forward, %s rad" % player.animator.leg_pitch())


func test_gun_arm_and_head_follow_the_look_pitch() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await run_seconds(0.3)
	var level_arm := player.animator.gun_arm_pitch()
	var level_head := player.animator.head_pitch()
	player.look(Vector2(0.0, -300.0))
	await run_seconds(0.3)
	var look_up := player.head.rotation.x
	assert_true(look_up > 0.3, "player looks up, %s rad" % look_up)
	assert_almost_eq(player.animator.gun_arm_pitch() - level_arm, look_up, 0.01, "gun arm rises with the look")
	assert_true(player.animator.head_pitch() > level_head + look_up * 0.3, "head tilts up")


func test_aiming_brings_the_free_arm_up_to_the_gun() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await run_seconds(0.3)
	assert_true(player.animator.free_arm_pitch() < 0.2, "free arm hangs down, %s rad" % player.animator.free_arm_pitch())
	Input.action_press("aim")
	await run_seconds(0.5)
	assert_almost_eq(player.animator.free_arm_pitch(), player.animator.gun_arm_pitch(), 0.02, "free arm holds the gun too")


func test_crouching_player_bends_its_knees() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	assert_almost_eq(player.animator.knee_pitch(), 0.0, 0.01, "knees straight while standing")
	Input.action_press("crouch")
	await run_seconds(0.5)
	assert_true(player.animator.knee_pitch() < -deg_to_rad(player.animator.knee_bend) * 1.8,
		"knees bend, %s rad" % player.animator.knee_pitch())
	Input.action_release("crouch")
	await run_seconds(0.5)
	assert_almost_eq(player.animator.knee_pitch(), 0.0, 0.02, "knees straighten when the player stands")

