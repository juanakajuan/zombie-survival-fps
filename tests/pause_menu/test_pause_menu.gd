extends TestCase

const SETTLE_FRAMES := 5


func test_esc_pauses_the_game_and_shows_the_menu() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap_escape()
	await physics_frames(2)
	assert_true(player.pause_menu.is_open(), "the menu shows")
	assert_true(get_tree().paused, "the game is paused")


func test_player_does_not_move_while_paused() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap_escape()
	await physics_frames(2)
	Input.action_press("move_forward")
	await physics_frames(30)
	assert_almost_eq(player.global_position.z, 0.0, 0.001, "z while paused")


func test_esc_again_resumes_the_game() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap_escape()
	await physics_frames(2)
	_tap_escape()
	await physics_frames(2)
	assert_true(not player.pause_menu.is_open(), "the menu is hidden")
	assert_true(not get_tree().paused, "the game runs")


func test_resume_click_does_not_fire_and_the_next_click_does() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	_tap_escape()
	await physics_frames(2)
	player.pause_menu.resume_button.pressed.emit()
	await physics_frames(3)
	assert_true(not get_tree().paused, "Resume resumes the game")
	assert_eq(weapon.ammo, weapon.data.magazine_size, "ammo after the Resume click")
	Input.action_press("fire")
	await physics_frames(2)
	assert_eq(weapon.ammo, weapon.data.magazine_size - 1, "ammo after the next click")


func test_dead_player_cannot_pause() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var health := Health.find_on(player)
	health.damage(health.max_health)
	_tap_escape()
	await physics_frames(2)
	assert_true(not player.pause_menu.is_open(), "the menu stays hidden")
	assert_true(not get_tree().paused, "the game is not paused")


func test_sensitivity_slider_scales_mouse_look() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.look(Vector2(100.0, 0.0))
	var default_turn := -player.rotation.y
	player.rotation.y = 0.0
	_tap_escape()
	await physics_frames(2)
	player.pause_menu.sensitivity_slider.value = 2.0
	_tap_escape()
	await physics_frames(2)
	player.look(Vector2(100.0, 0.0))
	assert_almost_eq(-player.rotation.y, default_turn * 2.0, 0.0001, "turn at 2x sensitivity")


func test_fov_slider_changes_the_camera_fov_at_once() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap_escape()
	await physics_frames(2)
	player.pause_menu.fov_slider.value = 100.0
	assert_almost_eq(player.camera.fov, 100.0, 0.001, "camera fov")


func test_settings_are_saved_on_resume_and_load_in_a_new_player() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap_escape()
	await physics_frames(2)
	player.pause_menu.fov_slider.value = 95.0
	player.pause_menu.volume_slider.value = 0.5
	_tap_escape()
	await physics_frames(2)
	player.queue_free()
	var next := await spawn_player(Vector3(5.0, 0.0, 0.0), SETTLE_FRAMES)
	assert_almost_eq(next.camera.fov, 95.0, 0.001, "fov in the new player")
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.5, 0.001, "master volume")
	next.pause_menu.volume_slider.value = 1.0


func test_bad_values_in_the_settings_file_give_the_defaults() -> void:
	var file := ConfigFile.new()
	file.set_value(GameSettings.SECTION, "field_of_view", "wide")
	file.set_value(GameSettings.SECTION, "fullscreen", 3)
	file.set_value(GameSettings.SECTION, "master_volume", 7.0)
	file.set_value(GameSettings.SECTION, "mouse_sensitivity_scale", 1.5)
	file.save(GameSettings.file_path)
	var loaded := GameSettings.load_saved()
	var defaults := GameSettings.new()
	assert_eq(loaded.field_of_view, defaults.field_of_view, "a string fov gives the default")
	assert_eq(loaded.fullscreen, defaults.fullscreen, "an int fullscreen gives the default")
	assert_eq(loaded.master_volume, 1.0, "the volume is clamped")
	assert_eq(loaded.mouse_sensitivity_scale, 1.5, "a good value loads")


func _tap_escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
