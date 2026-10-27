extends TestCase

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const SETTLE_FRAMES := 10
const SPEED_TOLERANCE := 0.2


func test_no_input_stays_on_floor_and_still() -> void:
	var player := await _spawn_player()
	var start := player.global_position
	await _run_seconds(1.0)
	assert_true(player.is_on_floor(), "player stays on the floor")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "feet stay at floor level")
	assert_almost_eq(_horizontal_speed(player), 0.0, 0.05, "horizontal speed stays near 0")
	assert_almost_eq(_horizontal_distance(start, player.global_position), 0.0, 0.05, "player does not drift")


func test_forward_moves_toward_negative_z_at_walk_speed() -> void:
	var player := await _spawn_player()
	Input.action_press("move_forward")
	await _run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")
	assert_true(player.global_position.z < -0.75 * player.walk_speed, "moved toward -Z, got z=%s" % player.global_position.z)
	assert_almost_eq(player.global_position.x, 0.0, 0.05, "no sideways drift")
	assert_true(not player.is_sprinting(), "walking is not sprinting")


func test_forward_follows_yaw() -> void:
	var player := await _spawn_player()
	player.look(Vector2((PI / 2.0) / player.mouse_sensitivity, 0.0))
	Input.action_press("move_forward")
	await _run_seconds(1.0)
	assert_true(player.global_position.x > 0.75 * player.walk_speed, "turning right 90 degrees makes forward +X, got x=%s" % player.global_position.x)
	assert_almost_eq(player.global_position.z, 0.0, 0.05, "no drift along the old forward axis")
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")


func test_sprint_forward_reaches_sprint_speed() -> void:
	var player := await _spawn_player()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.sprint_speed, SPEED_TOLERANCE, "speed is sprint_speed")
	assert_true(player.is_sprinting(), "is_sprinting is true")


func test_sprint_backward_stays_at_walk_speed() -> void:
	var player := await _spawn_player()
	Input.action_press("move_back")
	Input.action_press("sprint")
	await _run_seconds(1.0)
	assert_almost_eq(_horizontal_speed(player), player.walk_speed, SPEED_TOLERANCE, "speed is walk_speed")
	assert_true(player.global_position.z > 0.75 * player.walk_speed, "moved toward +Z, got z=%s" % player.global_position.z)
	assert_true(not player.is_sprinting(), "is_sprinting is false")


func test_sprint_without_move_input_is_not_sprinting() -> void:
	var player := await _spawn_player()
	Input.action_press("sprint")
	await physics_frames(5)
	assert_true(not player.is_sprinting(), "is_sprinting is false while standing")


func test_diagonal_is_not_faster_than_walk_speed() -> void:
	var player := await _spawn_player()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _run_seconds(1.0)
	var speed := _horizontal_speed(player)
	assert_true(speed <= player.walk_speed + 0.05, "diagonal speed %s exceeds walk_speed" % speed)
	assert_true(speed >= player.walk_speed - 0.3, "diagonal speed %s is far below walk_speed" % speed)
	assert_true(player.global_position.z < 0.0, "moved toward -Z")
	assert_true(player.global_position.x > 0.0, "moved toward +X")


func test_jump_leaves_floor_rises_and_lands() -> void:
	var player := await _spawn_player()
	Input.action_press("jump")
	await physics_frames(1)
	Input.action_release("jump")
	var expected_peak := pow(player.jump_velocity, 2.0) / (2.0 * _gravity())
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
	var player := await _spawn_player()
	Input.action_press("jump")
	await physics_frames(1)
	Input.action_release("jump")
	await _run_seconds(0.7)
	assert_true(not player.is_on_floor(), "player is still in the air")
	var velocity_before := player.velocity.y
	assert_true(velocity_before < 0.0, "player is falling, got vy=%s" % velocity_before)
	Input.action_press("jump")
	var highest := velocity_before
	for _i: int in 5:
		await physics_frames(1)
		highest = maxf(highest, player.velocity.y)
	assert_true(highest <= velocity_before + 0.01, "air jump added upward velocity: before %s, after %s" % [velocity_before, highest])


func test_look_up_clamps_pitch() -> void:
	var player := await _spawn_player()
	var head := player.get_node("Head") as Node3D
	player.look(Vector2(0.0, -1_000_000.0))
	assert_almost_eq(head.rotation_degrees.x, player.max_pitch_degrees, 0.01, "pitch clamps at +max")


func test_look_down_clamps_pitch() -> void:
	var player := await _spawn_player()
	var head := player.get_node("Head") as Node3D
	player.look(Vector2(0.0, 1_000_000.0))
	assert_almost_eq(head.rotation_degrees.x, -player.max_pitch_degrees, 0.01, "pitch clamps at -max")


func test_mouse_motion_turns_camera_the_expected_way() -> void:
	var player := await _spawn_player()
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var forward := -camera.global_basis.z
	assert_almost_eq(forward.z, -1.0, 0.001, "player starts facing -Z")
	player.look(Vector2(0.0, -100.0))
	forward = -camera.global_basis.z
	assert_true(forward.y > 0.1, "mouse up looks up, got forward.y=%s" % forward.y)
	player.look(Vector2(100.0, 0.0))
	forward = -camera.global_basis.z
	assert_true(forward.x > 0.1, "mouse right turns right, got forward.x=%s" % forward.x)


func test_camera_is_the_active_camera() -> void:
	var player := await _spawn_player()
	var camera := player.get_node("Head/Camera3D") as Camera3D
	assert_true(get_viewport().get_camera_3d() == camera, "player camera is current")
	assert_almost_eq(camera.fov, 80.0, 0.001, "fov is 80")
	assert_almost_eq(camera.global_position.y, 1.6, 0.05, "camera is at eye height")


func _spawn_player() -> Player:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await physics_frames(SETTLE_FRAMES)
	return player


func _run_seconds(seconds: float) -> void:
	await physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


func _horizontal_speed(player: Player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


func _gravity() -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return gravity
