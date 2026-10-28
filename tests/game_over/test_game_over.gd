extends TestCase

const ROUND_SETTINGS: RoundSettings = preload("res://rounds/round_settings.tres")


func test_game_over_is_hidden_while_the_player_lives() -> void:
	var level := await spawn_level()
	await physics_frames(5)
	assert_true(not _game_over(level).visible, "game over is hidden")


func test_death_shows_the_round_that_the_player_reached() -> void:
	var level := await spawn_level(_fast_round_settings())
	var manager := _round_manager(level)
	await physics_frames(5)
	await _clear_round(manager)
	assert_eq(manager.round_number, 2, "round after the first round is cleared")
	_kill(_player(level))
	await physics_frames(1)
	var game_over := _game_over(level)
	assert_true(game_over.visible, "game over shows after death")
	assert_eq(game_over.round_text(), "You reached round 2", "round text")


func test_death_releases_the_mouse_and_shows_game_over() -> void:
	var level := await spawn_level()
	await physics_frames(5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_kill(_player(level))
	await physics_frames(1)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "mouse mode after death")
	assert_true(_game_over(level).visible, "game over shows after death")


func test_restart_while_alive_does_nothing() -> void:
	var level := await spawn_level()
	var requests: Array[int] = [0]
	_game_over(level).restart_requested.connect(func() -> void: requests[0] += 1)
	await physics_frames(5)
	Input.action_press("restart")
	await physics_frames(3)
	assert_eq(requests[0], 0, "restart requests while alive")


func test_restart_after_death_loads_a_fresh_level() -> void:
	var old_level := LEVEL_SCENE.instantiate() as Level
	get_tree().root.add_child(old_level)
	get_tree().current_scene = old_level
	await physics_frames(5)
	var old_player := _player(old_level)
	var old_weapon := old_player.weapon
	old_weapon.try_fire()
	_kill(old_player)
	await physics_frames(1)
	Input.action_press("restart")
	await physics_frames(5)
	var level := get_tree().current_scene as Level
	assert_true(level != null and level != old_level, "a new level is the current scene")
	if level != null and level != old_level:
		var player := _player(level)
		var health := Health.find_on(player)
		var weapon := player.weapon
		assert_true(not player.is_dead(), "player is alive")
		assert_eq(health.current, health.max_health, "player health")
		assert_eq(weapon.ammo, weapon.data.magazine_size, "rounds in the magazine")
		assert_eq(_round_manager(level).round_number, 1, "round number")
		assert_true(not _game_over(level).visible, "game over is hidden")
	var current := get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()


func _fast_round_settings() -> RoundSettings:
	var settings := ROUND_SETTINGS.duplicate() as RoundSettings
	settings.spawn_interval = 0.02
	settings.break_time = 0.05
	return settings


func _clear_round(manager: RoundManager) -> void:
	var round_number := manager.round_number
	await physics_frames(roundi(manager.settings.spawn_interval * Engine.physics_ticks_per_second) * manager.settings.zombie_count(round_number) + 2)
	for child: Node in manager.get_children():
		if child is Zombie:
			Health.find_on(child).damage(1.0e6)
	await physics_frames(roundi(manager.settings.break_time * Engine.physics_ticks_per_second) + 3)


func _kill(player: Player) -> void:
	var health := Health.find_on(player)
	health.damage(health.max_health)


func _player(level: Level) -> Player:
	return level.get_node("Player") as Player


func _round_manager(level: Level) -> RoundManager:
	return level.get_node("RoundManager") as RoundManager


func _game_over(level: Level) -> GameOver:
	return level.game_over
