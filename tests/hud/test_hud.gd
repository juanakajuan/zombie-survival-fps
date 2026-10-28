extends TestCase

const FRAME_MARGIN := 2


func test_shows_full_health_and_magazine_at_start() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	assert_eq(player.hud.readout().health_text, "100", "health text")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo text")
	assert_true(not player.hud.readout().reloading, "reload label hidden")


func test_health_text_follows_damage_and_reset() -> void:
	var player := await spawn_player()
	var health := Health.find_on(player)
	health.damage(25.0)
	assert_eq(player.hud.readout().health_text, "75", "health after damage")
	health.damage(0.5)
	assert_eq(player.hud.readout().health_text, "75", "fractional health rounds up")
	health.reset()
	assert_eq(player.hud.readout().health_text, "100", "health after reset")


func test_ammo_text_follows_shots() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	assert_true(weapon.try_fire(), "shot fires")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size - 1, weapon.data.magazine_size], "ammo after one shot")


func test_reload_label_shows_during_reload_and_ammo_refills() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	weapon.try_fire()
	weapon.start_reload()
	assert_true(player.hud.readout().reloading, "reload label shown while reloading")
	await physics_frames(roundi(weapon.data.reload_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_true(not weapon.is_reloading(), "reload finished")
	assert_true(not player.hud.readout().reloading, "reload label hidden after reload")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo refilled")


func test_round_panel_is_hidden_without_a_round_manager() -> void:
	var player := await spawn_player()
	assert_true(not player.hud.readout().round_visible, "round panel hidden")


func test_round_number_shows_when_a_round_starts() -> void:
	var manager := _spawn_round_manager()
	var player := await spawn_player()
	assert_true(player.hud.readout().round_visible, "round panel shown")
	assert_eq(player.hud.readout().round_text, "1", "round text")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "round 1 is active")
	assert_true(not player.hud.readout().in_break, "break label hidden during a round")


func test_break_label_follows_round_end_and_next_round() -> void:
	var manager := _spawn_round_manager()
	var player := await spawn_player()
	_kill_zombies(manager)
	await physics_frames(2)
	assert_eq(manager.state, RoundManager.State.BREAK, "break after the last zombie")
	assert_true(player.hud.readout().in_break, "break label shown during the break")
	assert_eq(player.hud.readout().round_text, "1", "round text during the break")
	await physics_frames(roundi(manager.settings.break_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_eq(manager.round_number, 2, "round 2 started")
	assert_eq(player.hud.readout().round_text, "2", "round text after the break")
	assert_true(not player.hud.readout().in_break, "break label hidden in round 2")


func _spawn_round_manager() -> RoundManager:
	var settings := RoundSettings.new()
	settings.first_round_zombies = 1
	settings.first_round_speed = 0.0
	settings.break_time = 0.5
	var manager := RoundManager.new()
	manager.settings = settings
	var marker := Marker3D.new()
	marker.position = Vector3(0.0, 0.0, -6.0)
	manager.add_child(marker)
	add_child(manager)
	return manager


func _kill_zombies(manager: RoundManager) -> void:
	for child: Node in manager.get_children():
		if child is Zombie:
			Health.find_on(child).damage(1.0e6)
