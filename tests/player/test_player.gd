extends TestCase

const SETTLE_FRAMES := 10
const SPEED_TOLERANCE := 0.2


func test_no_input_stays_on_floor_and_still() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var start := player.global_position
	await run_seconds(1.0)
	assert_true(player.is_on_floor(), "player stays on the floor")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "feet stay at floor level")
	assert_almost_eq(_horizontal_speed(player), 0.0, 0.05, "horizontal speed stays near 0")
	assert_almost_eq(_horizontal_distance(start, player.global_position), 0.0, 0.05, "player does not drift")


func test_forward_moves_toward_negative_z_at_walk_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	await run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")
	assert_true(player.global_position.z < -0.75 * player.walk_speed, "moved toward -Z, got z=%s" % player.global_position.z)
	assert_almost_eq(player.global_position.x, 0.0, 0.05, "no sideways drift")
	assert_true(not player.is_sprinting(), "walking is not sprinting")


func test_forward_follows_yaw() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.look(Vector2((PI / 2.0) / player.mouse_sensitivity, 0.0))
	Input.action_press("move_forward")
	await run_seconds(1.0)
	assert_true(player.global_position.x > 0.75 * player.walk_speed, "turning right 90 degrees makes forward +X, got x=%s" % player.global_position.x)
	assert_almost_eq(player.global_position.z, 0.0, 0.05, "no drift along the old forward axis")
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")


func test_sprint_forward_reaches_sprint_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.sprint_speed, SPEED_TOLERANCE, "speed is sprint_speed")
	assert_true(player.is_sprinting(), "is_sprinting is true")


func test_sprint_backward_stays_at_walk_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_back")
	Input.action_press("sprint")
	await run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")
	assert_true(player.global_position.z > 0.75 * player.walk_speed, "moved toward +Z, got z=%s" % player.global_position.z)
	assert_true(not player.is_sprinting(), "is_sprinting is false")


func test_sprint_without_move_input_is_not_sprinting() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("sprint")
	await physics_frames(5)
	assert_true(not player.is_sprinting(), "is_sprinting is false while standing")


func test_diagonal_is_not_faster_than_walk_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await run_seconds(1.0)
	var speed := _horizontal_speed(player)
	assert_true(speed <= player.walk_speed + 0.05, "diagonal speed %s exceeds walk_speed" % speed)
	assert_true(speed >= player.walk_speed - 0.3, "diagonal speed %s is far below walk_speed" % speed)
	assert_true(player.global_position.z < 0.0, "moved toward -Z")
	assert_true(player.global_position.x > 0.0, "moved toward +X")


func test_jump_leaves_floor_rises_and_lands() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("jump")
	await physics_frames(1)
	Input.action_release("jump")
	var expected_peak := pow(player.jump_velocity, 2.0) / (2.0 * player.gravity)
	var peak := 0.0
	var left_floor := false
	var landed := false
	for _i: int in roundi(2.0 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		peak = maxf(peak, player.global_position.y)
		if not player.is_on_floor():
			left_floor = true
		elif left_floor:
			landed = true
			break
	assert_true(left_floor, "player left the floor")
	assert_almost_eq(peak, expected_peak, 0.15, "jump peak height")
	assert_true(landed, "player landed again")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "player is back at floor level")


func test_jump_in_air_adds_no_upward_velocity() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("jump")
	await physics_frames(1)
	Input.action_release("jump")
	# Three quarters of the air time: past the peak, before landing.
	await run_seconds(1.5 * player.jump_velocity / player.gravity)
	assert_true(not player.is_on_floor(), "player is still in the air")
	var velocity_before := player.velocity.y
	assert_true(velocity_before < 0.0, "player is falling, got vy=%s" % velocity_before)
	Input.action_press("jump")
	var highest := velocity_before
	for _i: int in 5:
		await physics_frames(1)
		highest = maxf(highest, player.velocity.y)
	assert_true(highest <= velocity_before + 0.01, "air jump added upward velocity: before %s, after %s" % [velocity_before, highest])


func test_holding_jump_hops_again_on_landing() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("jump")
	var takeoffs := 0
	var was_on_floor := true
	for _i: int in roundi(2.0 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		if was_on_floor and not player.is_on_floor():
			takeoffs += 1
		was_on_floor = player.is_on_floor()
	assert_true(takeoffs >= 2, "holding jump hops more than once, got %s takeoffs" % takeoffs)


func test_air_strafing_gains_speed_above_sprint_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	await run_seconds(1.0)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	Input.action_press("jump")
	var turn_per_frame := deg_to_rad(3.0) / player.mouse_sensitivity
	for _i: int in roundi(3.0 * Engine.physics_ticks_per_second):
		player.look(Vector2(turn_per_frame, 0.0))
		await physics_frames(1)
	assert_true(_horizontal_speed(player) > player.sprint_speed + 1.0, "air strafing reached %s m/s" % _horizontal_speed(player))


func test_no_input_in_the_air_keeps_horizontal_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	await run_seconds(1.0)
	Input.action_release("move_forward")
	Input.action_press("jump")
	await physics_frames(2)
	Input.action_release("jump")
	var speed_before := _horizontal_speed(player)
	await physics_frames(10)
	assert_true(not player.is_on_floor(), "player is in the air")
	assert_almost_eq(_horizontal_speed(player), speed_before, 0.01, "air speed is kept without input")


func test_crouch_lowers_the_camera_and_moves_at_crouch_speed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	var standing_eye := camera.global_position.y
	Input.action_press("crouch")
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await run_seconds(1.0)
	assert_true(player.is_crouching(), "is_crouching is true")
	assert_true(not player.is_sprinting(), "crouching is not sprinting")
	assert_true(camera.global_position.y < standing_eye - 0.5, "camera went down, got %s" % camera.global_position.y)
	assert_almost_eq(_horizontal_speed(player), player.crouch_speed, SPEED_TOLERANCE, "speed is crouch_speed")


func test_release_crouch_stands_up() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	var standing_eye := camera.global_position.y
	Input.action_press("crouch")
	await run_seconds(0.5)
	Input.action_release("crouch")
	await run_seconds(0.5)
	assert_true(not player.is_crouching(), "player stands up")
	assert_almost_eq(camera.global_position.y, standing_eye, 0.01, "camera is back at standing height")


func test_body_is_hidden_from_own_camera_and_shrinks_when_crouched() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	var body := player.body
	assert_true(camera.cull_mask & body.layers == 0, "own camera does not draw the body")
	assert_almost_eq(body.get_aabb().size.y, 1.8, 0.01, "standing body is 1.8 m tall")
	Input.action_press("crouch")
	await run_seconds(0.2)
	assert_almost_eq(body.get_aabb().size.y, player.crouch_height, 0.01, "crouched body is crouch_height tall")
	assert_almost_eq(body.global_position.y - player.global_position.y, player.crouch_height / 2.0, 0.01, "crouched body stands on the feet")


func test_only_a_crouched_player_fits_under_a_low_ceiling() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_add_box(Vector3(0.0, 1.4, -3.0), Vector3(4.0, 0.4, 2.0))
	Input.action_press("move_forward")
	await run_seconds(1.5)
	assert_true(player.global_position.z > -2.0 + 0.3, "standing player is stopped by the ceiling, got z=%s" % player.global_position.z)
	Input.action_press("crouch")
	await run_seconds(1.5)
	assert_true(player.global_position.z < -2.5, "crouched player goes under, got z=%s" % player.global_position.z)


func test_player_stays_crouched_under_a_low_ceiling() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("crouch")
	await run_seconds(0.2)
	_add_box(Vector3(0.0, 1.4, 0.0), Vector3(4.0, 0.4, 4.0))
	await physics_frames(2)
	Input.action_release("crouch")
	await run_seconds(0.5)
	assert_true(player.is_crouching(), "player cannot stand under the ceiling")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "player is not pushed through the ceiling")


func test_look_up_clamps_pitch() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var head := player.head
	player.look(Vector2(0.0, -1_000_000.0))
	assert_almost_eq(head.rotation_degrees.x, player.max_pitch_degrees, 0.01, "pitch clamps at +max")


func test_look_down_clamps_pitch() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var head := player.head
	player.look(Vector2(0.0, 1_000_000.0))
	assert_almost_eq(head.rotation_degrees.x, -player.max_pitch_degrees, 0.01, "pitch clamps at -max")


func test_mouse_motion_turns_camera_the_expected_way() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	var forward := -camera.global_basis.z
	assert_almost_eq(forward.z, -1.0, 0.001, "player starts facing -Z")
	player.look(Vector2(0.0, -100.0))
	forward = -camera.global_basis.z
	assert_true(forward.y > 0.1, "mouse up looks up, got forward.y=%s" % forward.y)
	player.look(Vector2(100.0, 0.0))
	forward = -camera.global_basis.z
	assert_true(forward.x > 0.1, "mouse right turns right, got forward.x=%s" % forward.x)


func test_camera_stays_on_the_head_while_walking_and_turning() -> void:
	assert_true(get_tree().physics_interpolation, "physics interpolation is on, so the camera moves smoothly on fast screens")
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	Input.action_press("move_forward")
	for _i: int in 20:
		player.look(Vector2(10.0, 0.0))
		await physics_frames(1)
		await get_tree().process_frame
	assert_true(player.global_position.length() > 1.0, "player walked, got %s" % player.global_position)
	assert_true(camera.global_position.distance_to(player.head.global_position) < 0.2, "camera is at the head")
	var forward := -camera.global_basis.z
	var facing := -player.global_basis.z
	assert_almost_eq(forward.dot(facing), 1.0, 0.001, "camera faces where the player faces")


func test_camera_is_the_active_camera() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var camera := player.camera
	assert_true(get_viewport().get_camera_3d() == camera, "player camera is current")
	assert_almost_eq(camera.fov, 80.0, 0.001, "fov is 80")
	assert_almost_eq(camera.global_position.y, 1.6, 0.05, "camera is at eye height")


func test_dying_emits_died_once() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var deaths: Array[int] = [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	var health := Health.find_on(player)
	health.damage(health.max_health)
	health.damage(10.0)
	assert_eq(deaths[0], 1, "died emits once")
	assert_true(player.is_dead(), "is_dead is true")


func test_dead_player_does_not_move_or_jump() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_kill(player)
	var start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("jump")
	await run_seconds(1.0)
	assert_almost_eq(_horizontal_distance(start, player.global_position), 0.0, 0.05, "dead player does not move")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "dead player does not jump")
	assert_true(not player.is_sprinting(), "dead player is not sprinting")


func test_player_that_dies_while_moving_stops() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	await run_seconds(0.5)
	_kill(player)
	await run_seconds(0.5)
	assert_almost_eq(_horizontal_speed(player), 0.0, 0.05, "dead player comes to a stop")


func test_dead_player_in_the_air_falls_to_the_floor() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("jump")
	await physics_frames(5)
	Input.action_release("jump")
	assert_true(not player.is_on_floor(), "player is in the air")
	_kill(player)
	await run_seconds(1.5)
	assert_true(player.is_on_floor(), "dead player lands")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "dead player is at floor level")


func test_dead_player_cannot_look() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var head := player.head
	_kill(player)
	player.look(Vector2(100.0, -100.0))
	assert_almost_eq(player.rotation.y, 0.0, 0.0001, "yaw does not change")
	assert_almost_eq(head.rotation.x, 0.0, 0.0001, "pitch does not change")


func test_dead_player_cannot_fire_or_reload() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	Input.action_press("fire")
	await physics_frames(2)
	Input.action_release("fire")
	var ammo_before := weapon.ammo
	assert_true(ammo_before < weapon.data.magazine_size, "the live player fired a shot")
	_kill(player)
	Input.action_press("fire")
	await physics_frames(2)
	Input.action_release("fire")
	Input.action_press("reload")
	await physics_frames(2)
	assert_eq(weapon.ammo, ammo_before, "dead player does not fire")
	assert_true(not weapon.is_reloading(), "dead player does not reload")


func test_click_after_death_does_not_enable_the_trigger() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	_kill(player)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frames(2)
	Input.action_press("fire")
	await physics_frames(2)
	assert_eq(weapon.ammo, weapon.data.magazine_size, "dead player does not fire after a click")


func _kill(player: Player) -> void:
	var health := Health.find_on(player)
	health.damage(health.max_health)


func _add_box(center: Vector3, size: Vector3) -> void:
	add_child(_box(size, center))


func _horizontal_speed(player: Player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

