extends TestCase

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const FRAME_MARGIN := 2


func test_shows_full_health_and_magazine_at_start() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	assert_eq(_label(player, "HealthValue").text, "100", "health text")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo text")
	assert_true(not _label(player, "ReloadLabel").is_visible_in_tree(), "reload label hidden")


func test_health_text_follows_damage_and_reset() -> void:
	var player := await _spawn_player()
	var health := Health.find_on(player)
	health.damage(25.0)
	assert_eq(_label(player, "HealthValue").text, "75", "health after damage")
	health.damage(0.5)
	assert_eq(_label(player, "HealthValue").text, "75", "fractional health rounds up")
	health.reset()
	assert_eq(_label(player, "HealthValue").text, "100", "health after reset")


func test_ammo_text_follows_shots() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	assert_true(weapon.try_fire(), "shot fires")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size - 1, weapon.data.magazine_size], "ammo after one shot")


func test_reload_label_shows_during_reload_and_ammo_refills() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	weapon.try_fire()
	weapon.start_reload()
	assert_true(_label(player, "ReloadLabel").is_visible_in_tree(), "reload label shown while reloading")
	await physics_frames(roundi(weapon.data.reload_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_true(not weapon.is_reloading(), "reload finished")
	assert_true(not _label(player, "ReloadLabel").is_visible_in_tree(), "reload label hidden after reload")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo refilled")


func test_round_panel_is_hidden_without_a_round_manager() -> void:
	var player := await _spawn_player()
	assert_true(not _round_panel(player).is_visible_in_tree(), "round panel hidden")


func test_round_number_shows_when_a_round_starts() -> void:
	var manager := _spawn_round_manager()
	var player := await _spawn_player()
	assert_true(_round_panel(player).is_visible_in_tree(), "round panel shown")
	assert_eq(_label(player, "RoundValue").text, "1", "round text")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "round 1 is active")
	assert_true(not _label(player, "BreakLabel").is_visible_in_tree(), "break label hidden during a round")


func test_break_label_follows_round_end_and_next_round() -> void:
	var manager := _spawn_round_manager()
	var player := await _spawn_player()
	_kill_zombies(manager)
	await physics_frames(2)
	assert_eq(manager.state, RoundManager.State.BREAK, "break after the last zombie")
	assert_true(_label(player, "BreakLabel").is_visible_in_tree(), "break label shown during the break")
	assert_eq(_label(player, "RoundValue").text, "1", "round text during the break")
	await physics_frames(roundi(manager.settings.break_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_eq(manager.round_number, 2, "round 2 started")
	assert_eq(_label(player, "RoundValue").text, "2", "round text after the break")
	assert_true(not _label(player, "BreakLabel").is_visible_in_tree(), "break label hidden in round 2")


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


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await physics_frames(1)
	return player


func _weapon(player: Player) -> Weapon:
	return player.get_node("Head/Camera3D/Weapon") as Weapon


func _label(player: Player, unique_name: String) -> Label:
	return player.get_node("Hud").get_node("%" + unique_name) as Label


func _round_panel(player: Player) -> Control:
	return player.get_node("Hud").get_node("%RoundPanel") as Control
