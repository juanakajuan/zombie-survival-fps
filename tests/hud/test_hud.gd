extends TestCase

const FRAME_MARGIN := 2


func test_shows_full_health_and_magazine_at_start() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	assert_eq(player.hud.readout().health_text, "100", "health text")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size, weapon.data.max_reserve], "ammo text")
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


func test_red_edge_grows_as_health_gets_low_and_goes_when_it_comes_back() -> void:
	var player := await spawn_player()
	player.hud.low_health_fraction = 0.3
	assert_almost_eq(player.hud.readout().low_health_vignette, 0.0, 0.001, "hidden at full health")
	player.health.damage(75.0)
	assert_almost_eq(player.hud.readout().low_health_vignette, 1.0 / 6.0, 0.01, "faint at 25 hp")
	player.health.damage(20.0)
	assert_almost_eq(player.hud.readout().low_health_vignette, 5.0 / 6.0, 0.01, "strong at 5 hp")
	await run_seconds(player.health.regen_delay + 2.0)
	assert_almost_eq(player.hud.readout().low_health_vignette, 0.0, 0.001, "hidden after health comes back")


func test_fps_counter_is_hidden_until_turned_on() -> void:
	var player := await spawn_player()
	assert_true(not player.hud.readout().fps_visible, "hidden by default")
	player.hud.show_fps = true
	await physics_frames(2)
	assert_true(player.hud.readout().fps_visible, "shown when on")
	assert_eq(player.hud.readout().fps_text, "%d FPS" % roundi(Engine.get_frames_per_second()), "fps text")


func test_ammo_text_follows_shots() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	assert_true(weapon.try_fire(), "shot fires")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size - 1, weapon.data.max_reserve], "ammo after one shot")


func test_reload_label_shows_during_reload_and_ammo_refills() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	weapon.try_fire()
	weapon.start_reload()
	assert_true(player.hud.readout().reloading, "reload label shown while reloading")
	await physics_frames(roundi(weapon.data.reload_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_true(not weapon.is_reloading(), "reload finished")
	assert_true(not player.hud.readout().reloading, "reload label hidden after reload")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [weapon.data.magazine_size, weapon.data.max_reserve - 1], "magazine refilled from the reserve")


func test_round_panel_is_hidden_without_a_round_manager() -> void:
	var player := await spawn_player()
	assert_true(not player.hud.readout().round_visible, "round panel hidden")


func test_round_number_shows_when_a_round_starts() -> void:
	var manager := _spawn_round_manager()
	var player := await spawn_player()
	player.hud.round_manager = manager
	assert_true(player.hud.readout().round_visible, "round panel shown")
	assert_eq(player.hud.readout().round_text, "1", "round text")
	assert_eq(manager.state, RoundManager.State.ACTIVE, "round 1 is active")
	assert_true(not player.hud.readout().in_break, "break label hidden during a round")


func test_break_label_follows_round_end_and_next_round() -> void:
	var manager := _spawn_round_manager()
	var player := await spawn_player()
	player.hud.round_manager = manager
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
	var marker := SpawnPoint.new()
	marker.position = Vector3(0.0, 0.0, -6.0)
	manager.add_child(marker)
	add_child(manager)
	return manager


func _kill_zombies(manager: RoundManager) -> void:
	for child: Node in manager.get_children():
		if child is Zombie:
			Health.find_on(child).damage(1.0e6)


func test_shows_the_weapon_name() -> void:
	var player := await spawn_player()
	assert_eq(player.hud.readout().weapon_name, player.weapon.data.display_name, "weapon name")


func test_objective_counts_zombies_left_and_the_break() -> void:
	var manager := _spawn_round_manager()
	var player := await spawn_player()
	player.hud.round_manager = manager
	assert_eq(player.hud.readout().objective_text, "1 LEFT", "zombies left in round 1")
	_kill_zombies(manager)
	await physics_frames(2)
	assert_eq(player.hud.readout().objective_text, "NEXT ROUND IN 1", "break countdown")


func test_hit_marker_shows_when_a_shot_hits_a_target() -> void:
	var player := await spawn_player()
	await spawn_dummy(Vector3(0.0, 0.0, -4.0))
	assert_true(not player.hud.readout().hit_marker, "no hit marker before the shot")
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_true(player.hud.readout().hit_marker, "hit marker after a hit")


func test_headshot_marker_shows_after_a_headshot_and_not_after_a_body_shot() -> void:
	var player := await spawn_player()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -4.0))
	await physics_frames(FRAME_MARGIN)
	look_at_point(player, zombie.global_position + Vector3.UP)
	assert_true(player.weapon.try_fire(), "body shot fires")
	assert_true(player.hud.readout().hit_marker, "hit marker after a body shot")
	assert_true(not player.hud.readout().headshot_marker, "no headshot marker after a body shot")
	await run_seconds(player.weapon.data.fire_interval + FRAME_MARGIN / 60.0)
	look_at_point(player, zombie.weak_spot.global_position)
	assert_true(player.weapon.try_fire(), "head shot fires")
	assert_true(player.hud.readout().hit_marker, "hit marker after a headshot")
	assert_true(player.hud.readout().headshot_marker, "headshot marker after a headshot")


func test_crosshair_hides_while_aiming() -> void:
	var player := await spawn_player()
	await physics_frames(FRAME_MARGIN)
	assert_true(player.hud.readout().crosshair_visible, "crosshair shown at start")
	Input.action_press("aim")
	await physics_frames(FRAME_MARGIN)
	assert_true(not player.hud.readout().crosshair_visible, "crosshair hidden while aiming")
	Input.action_release("aim")
	await physics_frames(FRAME_MARGIN)
	assert_true(player.hud.readout().crosshair_visible, "crosshair back after aiming")


func test_points_show_the_balance_and_follow_it() -> void:
	var player := await spawn_player()
	assert_eq(player.hud.readout().points_text, "0", "no points at start")
	player.wallet.add(70)
	assert_eq(player.hud.readout().points_text, "70", "after earning")
	player.wallet.spend(20)
	assert_eq(player.hud.readout().points_text, "50", "after spending")


func test_ammo_text_shows_the_reserve_and_follows_a_refill() -> void:
	var player := await spawn_player()
	player.weapon.reserve = 7
	assert_eq(player.hud.readout().ammo_text, "%d / 7" % player.weapon.data.magazine_size, "reserve in the ammo text")
	player.weapon.refill_reserve()
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [player.weapon.data.magazine_size, player.weapon.data.max_reserve], "after a refill")


func test_prompt_shows_only_while_looking_at_a_station() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(Vector3(0.0, 0.0, -2.0))
	await physics_frames(2)
	assert_true(not player.hud.readout().prompt_visible, "no prompt before looking")
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	assert_true(player.hud.readout().prompt_visible, "prompt while looking")
	assert_eq(player.hud.readout().prompt_text, station.prompt_text(player), "prompt text")
	player.look(Vector2(1000.0, 0.0))
	await physics_frames(2)
	assert_true(not player.hud.readout().prompt_visible, "prompt gone after looking away")
