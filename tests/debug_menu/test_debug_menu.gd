extends TestCase

const SETTLE_FRAMES := 3
const DEBUG_MENU_SCENE: PackedScene = preload("res://debug_menu/debug_menu.tscn")


func test_debug_action_opens_the_menu_and_pauses() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"debug_menu")
	await physics_frames(2)
	assert_true(player.debug_menu.is_open(), "the menu shows")
	assert_true(get_tree().paused, "the game is paused")
	assert_true(not player.pause_menu.is_open(), "the pause menu stays closed")


func test_debug_action_closes_the_menu() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"debug_menu")
	await physics_frames(2)
	_tap(&"debug_menu")
	await physics_frames(2)
	assert_true(not player.debug_menu.is_open(), "the menu hides")
	assert_true(not get_tree().paused, "the game runs")


func test_esc_closes_the_menu_and_does_not_open_the_pause_menu() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"debug_menu")
	await physics_frames(2)
	_tap(&"ui_cancel")
	await physics_frames(2)
	assert_true(not player.debug_menu.is_open(), "the menu hides")
	assert_true(not player.pause_menu.is_open(), "the pause menu stays closed")
	assert_true(not get_tree().paused, "the game runs")


func test_close_button_closes_the_menu() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"debug_menu")
	await physics_frames(2)
	player.debug_menu.close_button.pressed.emit()
	await physics_frames(2)
	assert_true(not player.debug_menu.is_open(), "the menu hides")
	assert_true(not get_tree().paused, "the game runs")


func test_debug_action_does_nothing_while_the_pause_menu_is_open() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"ui_cancel")
	await physics_frames(2)
	_tap(&"debug_menu")
	await physics_frames(2)
	assert_true(player.pause_menu.is_open(), "the pause menu stays open")
	assert_true(not player.debug_menu.is_open(), "the debug menu stays closed")


func test_points_commands_add_the_grant() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var menu := player.debug_menu
	for grant: int in menu.point_grants:
		var before := player.wallet.points
		menu.run_command("+%d POINTS" % grant)
		assert_eq(player.wallet.points, before + grant, "points after +%d" % grant)
	assert_eq(player.hud.readout().points_text, str(player.wallet.points), "the HUD shows the points")


func test_give_weapon_equips_it_and_fills_the_ammo() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var data := WeaponData.new()
	data.display_name = "TEST GUN"
	data.magazine_size = 7
	data.max_reserve = 21
	var menu := _menu_giving(player, data)
	menu.run_command("GIVE TEST GUN")
	assert_eq(player.weapon.data, data, "the weapon data")
	assert_eq(player.hud.readout().weapon_name, "TEST GUN", "the HUD weapon name")
	assert_eq(player.hud.readout().ammo_text, "7 / 21", "the HUD ammo")


func test_menu_lists_a_give_command_for_each_weapon_of_the_scene() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	for data: WeaponData in player.debug_menu.weapons:
		assert_true("GIVE " + data.display_name in player.debug_menu.command_labels(), "command for %s" % data.display_name)


func test_give_weapon_in_third_person_keeps_the_new_model_hidden() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_tap(&"third_person")
	await physics_frames(2)
	player.debug_menu.run_command("GIVE " + player.weapon.data.display_name)
	await physics_frames(2)
	assert_true(player.is_third_person(), "third person is still on")
	assert_true(not player.weapon.view_model.is_visible_in_tree(), "the new first-person gun is hidden")


func test_refill_ammo_fills_the_magazine_and_the_reserve() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	weapon.try_fire()
	weapon.reserve = 1
	player.debug_menu.run_command("REFILL AMMO")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size, weapon.data.max_reserve], "HUD ammo")


func test_full_health_restores_the_health() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.health.damage(60.0)
	player.debug_menu.run_command("FULL HEALTH")
	assert_eq(player.hud.readout().health_text, str(ceili(player.health.max_health)), "HUD health")


func test_god_mode_blocks_damage_until_it_is_toggled_off() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var menu := player.debug_menu
	menu.run_command("GOD MODE")
	assert_eq(menu.god_mode_text(), "GOD MODE: ON", "button text")
	player.health.damage(50.0)
	assert_eq(player.hud.readout().health_text, str(ceili(player.health.max_health)), "health under god mode")
	menu.run_command("GOD MODE")
	assert_eq(menu.god_mode_text(), "GOD MODE: OFF", "button text after the second press")
	player.health.damage(50.0)
	assert_eq(player.hud.readout().health_text, str(ceili(player.health.max_health) - 50), "health after god mode")


func test_kill_all_zombies_ends_the_round_and_gives_no_points() -> void:
	var level := await spawn_level()
	await physics_frames(2)
	var manager := level.round_manager
	assert_eq(manager.zombies_left(), ROUND_SETTINGS.zombie_count(1), "zombies in round 1, most not spawned yet")
	var points := level.player.wallet.points
	level.player.debug_menu.run_command("KILL ALL ZOMBIES")
	assert_eq(manager.zombies_left(), 0, "zombies left")
	assert_eq(manager.state, RoundManager.State.BREAK, "the break starts")
	assert_eq(level.player.wallet.points, points, "points")


func test_skip_break_starts_the_next_round() -> void:
	var level := await spawn_level(_one_zombie_settings())
	await physics_frames(2)
	var manager := level.round_manager
	level.player.debug_menu.run_command("SKIP BREAK")
	assert_eq(manager.round_number, 1, "skip during a round does nothing")
	level.player.debug_menu.run_command("KILL ALL ZOMBIES")
	level.player.debug_menu.run_command("SKIP BREAK")
	assert_eq(manager.round_number, 2, "round number")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "state")
	assert_eq(level.player.hud.readout().round_text, "2", "the HUD round")


func test_skip_break_without_a_level_does_nothing() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.debug_menu.run_command("SKIP BREAK")
	assert_true(not get_tree().paused, "no error and the game runs")


func _one_zombie_settings() -> RoundSettings:
	var settings := RoundSettings.new()
	settings.first_round_zombies = 1
	settings.zombies_per_round = 1
	settings.first_round_speed = 0.0
	settings.speed_per_round = 0.0
	settings.break_time = 30.0
	return settings


## A menu like the player's, whose weapon commands give `data`.
func _menu_giving(player: Player, data: WeaponData) -> DebugMenu:
	var menu := DEBUG_MENU_SCENE.instantiate() as DebugMenu
	menu.weapons = [data] as Array[WeaponData]
	menu.player = player
	add_child(menu)
	return menu


func _tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
