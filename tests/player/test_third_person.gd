extends TestCase

const SETTLE_FRAMES := 3


func test_third_person_puts_the_camera_behind_the_player_and_shows_the_body() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_press_third_person()
	await physics_frames(2)
	var camera := player.camera
	assert_true(player.is_third_person(), "third person is on")
	var behind := camera.global_position - player.head.global_position
	assert_almost_eq(behind.length(), Vector2(player.third_person_distance, player.third_person_shoulder).length(), 0.05,
		"camera is behind the head")
	assert_true(behind.dot(-camera.global_basis.z) < 0.0, "camera looks toward the player")
	for mesh: MeshInstance3D in player.body.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "camera draws %s" % mesh.name)
	assert_true(not player.weapon.view_model.is_visible_in_tree(), "the first-person gun hides")
	_press_third_person()
	await physics_frames(2)
	assert_almost_eq(camera.global_position.distance_to(player.head.global_position), 0.0, 0.05, "camera is back in the head")
	assert_true(player.weapon.view_model.is_visible_in_tree(), "the first-person gun shows again")


func test_third_person_camera_stops_short_of_a_wall() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 2.0, 1.5)
	add_child(wall)
	_press_third_person()
	await physics_frames(2)
	assert_true(player.camera.global_position.z < 1.3, "camera stays in front of the wall, z %s" % player.camera.global_position.z)


func test_third_person_shot_starts_at_the_head_not_the_camera() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await spawn_dummy(Vector3(0.0, 0.0, -5.0))
	_press_third_person()
	await physics_frames(2)
	var points: Array[Vector3] = []
	player.weapon.hit.connect(func(_collider: Object, point: Vector3) -> void: points.append(point))
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_eq(points.size(), 1, "shot hits the dummy")
	assert_almost_eq(points[0].x, player.head.global_position.x, 0.01, "shot is in line with the head, not the shoulder camera")

func _press_third_person() -> void:
	var event := InputEventAction.new()
	event.action = &"third_person"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
