extends TestCase

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const MODEL_PATH := "Head/Camera3D/Weapon/PistolView/Motion/Model"
const SETTLE_FRAMES := 60


func test_gun_rises_into_view_after_spawn() -> void:
	var player := await _spawn_player(1)
	var start := _pose(player).origin
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose(player).origin.y > start.y + 0.05, "the gun moves up into view")


func test_shot_kicks_the_gun_back_and_it_returns() -> void:
	var player := await _spawn_player(SETTLE_FRAMES)
	var rest := _pose(player)
	Input.action_press("fire")
	await physics_frames(2)
	var kicked := _pose(player)
	assert_true(kicked.origin.z > rest.origin.z + 0.01, "the gun moves back toward the camera")
	assert_true(_muzzle_pitch(kicked) > _muzzle_pitch(rest) + 0.05, "the muzzle points up")
	Input.action_release("fire")
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose(player).origin.distance_to(rest.origin) < 0.005, "the gun is back at rest")


func test_reload_throws_the_gun_behind_the_player_and_draws_a_new_one() -> void:
	var player := await _spawn_player(SETTLE_FRAMES)
	var weapon := player.get_node("Head/Camera3D/Weapon") as Weapon
	var model := player.get_node(MODEL_PATH) as Node3D
	var rest := _pose(player)
	weapon.try_fire()
	await physics_frames(SETTLE_FRAMES)
	weapon.start_reload()
	var hands_were_empty := false
	var frames := ceili(weapon.data.reload_time * Engine.physics_ticks_per_second) + 10
	for i in frames:
		await physics_frames(1)
		if not model.is_visible_in_tree():
			hands_were_empty = true
	assert_true(hands_were_empty, "the gun leaves the hand during the reload")
	var thrown := get_tree().get_nodes_in_group("thrown_gun")
	assert_eq(thrown.size(), 1, "one gun was thrown")
	var gun := thrown[0] as Node3D
	assert_true(gun.global_position.z > player.global_position.z + 0.5, "the thrown gun is behind the player")
	assert_true(not weapon.is_reloading(), "the reload is over")
	assert_true(model.is_visible_in_tree(), "a new gun is in the hand")
	assert_true(_pose(player).origin.distance_to(rest.origin) < 0.005, "the new gun is at rest")


func test_sprinting_points_the_gun_away_from_the_crosshair() -> void:
	var player := await _spawn_player(SETTLE_FRAMES)
	var rest := _pose(player)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await physics_frames(SETTLE_FRAMES)
	assert_true(player.is_sprinting(), "the player sprints")
	var forward := -_pose(player).basis.z
	assert_true(forward.angle_to(-rest.basis.z) > deg_to_rad(15.0), "the gun turns away from the crosshair")


func test_walking_bobs_the_gun() -> void:
	var player := await _spawn_player(SETTLE_FRAMES)
	Input.action_press("move_forward")
	var lowest := INF
	var highest := -INF
	for i in SETTLE_FRAMES:
		await physics_frames(1)
		var y := _pose(player).origin.y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	assert_true(highest - lowest > 0.005, "the gun moves up and down while walking")


func test_gun_goes_down_when_the_player_dies() -> void:
	var player := await _spawn_player(SETTLE_FRAMES)
	var rest := _pose(player)
	Health.find_on(player).damage(10000.0)
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose(player).origin.y < rest.origin.y - 0.1, "the gun drops out of view")


## The model's transform as the camera sees it.
func _pose(player: Player) -> Transform3D:
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var model := player.get_node(MODEL_PATH) as Node3D
	return camera.global_transform.affine_inverse() * model.global_transform


func _muzzle_pitch(pose: Transform3D) -> float:
	return asin(clampf(-pose.basis.z.y, -1.0, 1.0))


func _spawn_player(frames: int) -> Player:
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
	await physics_frames(frames)
	return player
