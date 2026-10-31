extends TestCase

const SETTLE_FRAMES := 5
const FRAME_MARGIN := 3


func _tap_melee() -> void:
	Input.action_press("melee")
	await physics_frames(2)
	Input.action_release("melee")


func _swing_seconds(player: Player) -> float:
	return player.melee.wind_up_time + player.melee.recover_time


func _still_zombie(at: Vector3, player: Player) -> Zombie:
	var zombie := spawn_zombie(at, player)
	zombie.move_speed = 0.0
	return zombie


func test_a_tap_damages_a_zombie_in_front_once() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -1.2), player)
	var health := Health.find_on(zombie)
	var before := health.current
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_almost_eq(health.current, before - player.melee.damage, 0.001, "one swing takes melee.damage")


func test_a_punch_never_reports_a_headshot() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_still_zombie(Vector3(0.0, 0.0, -1.2), player)
	var reports: Array[bool] = []
	player.melee.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: reports.append(headshot))
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_eq(reports, [false] as Array[bool], "one punch hit and it was not a headshot")


func test_a_zombie_behind_or_far_in_front_takes_no_damage() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var behind := _still_zombie(Vector3(0.0, 0.0, 1.2), player)
	var far := _still_zombie(Vector3(0.0, 0.0, -3.0), player)
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_almost_eq(Health.find_on(behind).current, Health.find_on(behind).max_health, 0.001, "the zombie behind is unharmed")
	assert_almost_eq(Health.find_on(far).current, Health.find_on(far).max_health, 0.001, "the zombie 3 m away is unharmed")


func test_a_press_during_the_swing_does_nothing_and_a_new_swing_works_after_it() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -1.2), player)
	var health := Health.find_on(zombie)
	var swings := [0]
	player.melee.swung.connect(func() -> void: swings[0] += 1)
	await _tap_melee()
	assert_true(player.is_meleeing(), "the swing is on")
	await _tap_melee()
	assert_eq(swings[0], 1, "the second press during the swing starts nothing")
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_true(not player.is_meleeing(), "the swing ends")
	assert_almost_eq(health.current, health.max_health - player.melee.damage, 0.001, "the zombie was hit once")
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_eq(swings[0], 2, "a new swing starts after the first ends")
	assert_almost_eq(health.current, health.max_health - 2.0 * player.melee.damage, 0.001, "the second swing hits too")


func test_a_dead_player_cannot_punch() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.downed_time = 0.0
	Health.find_on(player).damage(1.0e6)
	assert_true(not player.melee.try_swing(), "no swing")
	await _tap_melee()
	assert_true(not player.is_meleeing(), "the press starts nothing")


func test_the_pistol_cannot_fire_or_reload_during_the_swing() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var ammo := player.weapon.ammo
	player.weapon.try_fire()
	ammo -= 1
	await run_seconds(player.weapon.data.fire_interval + 0.05)
	await _tap_melee()
	assert_true(player.is_meleeing(), "the swing is on")
	assert_true(not player.weapon.try_fire(), "no shot during the swing")
	player.weapon.start_reload()
	assert_true(not player.weapon.is_reloading(), "no reload during the swing")
	assert_eq(player.weapon.ammo, ammo, "the ammo stays the same")
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_true(player.weapon.try_fire(), "the pistol fires again after the swing")


func test_a_punch_gives_points_and_a_killing_punch_gives_the_kill_bonus() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -1.2), player)
	var health := Health.find_on(zombie)
	health.current = player.melee.damage * 1.5
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_eq(player.wallet.points, player.wallet.points_per_hit, "a hit gives points")
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_eq(player.wallet.points, 2 * player.wallet.points_per_hit + player.wallet.kill_bonus, "the kill gives the bonus too")


func test_a_punch_on_a_dummy_gives_no_points() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await spawn_dummy(Vector3(0.0, 0.0, -1.2))
	await _tap_melee()
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_eq(player.wallet.points, 0, "dummies give no points")


func test_the_fist_shows_during_the_swing_and_hides_after_it() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	assert_true(not player.punch_view.is_hand_visible(), "hidden while ready")
	await _tap_melee()
	await physics_frames(FRAME_MARGIN)
	assert_true(player.punch_view.is_hand_visible(), "shown in the swing")
	await run_seconds(_swing_seconds(player) + 0.1)
	assert_true(not player.punch_view.is_hand_visible(), "hidden after the swing")


func test_the_fist_jabs_forward() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var hand := player.punch_view.hand
	await _tap_melee()
	var zs := await sample_range(func() -> float: return hand.position.z, _swing_seconds(player))
	assert_true(zs.y - zs.x > 0.25, "the fist moves out from the camera and back, %s to %s" % [zs.y, zs.x])


func test_the_free_arm_rises_in_the_swing() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var rest := player.animator.free_arm_pitch()
	await _tap_melee()
	var pitches := await sample_range(func() -> float: return player.animator.free_arm_pitch(), _swing_seconds(player))
	assert_true(pitches.y > rest + deg_to_rad(player.animator.punch_lift) * 0.8, "the arm lifts, max %s rad" % pitches.y)
	await run_seconds(0.2)
	assert_almost_eq(player.animator.free_arm_pitch(), rest, 0.05, "the arm comes back")


func test_the_gun_dips_during_the_swing() -> void:
	var player := await spawn_player(Vector3.ZERO, 60)
	var motion := player.weapon.view_model.motion
	var rest := motion.position.y
	await _tap_melee()
	var ys := await sample_range(func() -> float: return motion.position.y, _swing_seconds(player))
	assert_true(ys.x < rest - 0.03, "the gun moves down, min %s from %s" % [ys.x, rest])
