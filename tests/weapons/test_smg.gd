extends TestCase

const SMG: WeaponData = preload("res://weapons/smg.tres")


func test_the_smg_has_the_magazine_and_reserve_of_its_data() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	assert_eq(smg.data.display_name, "SMG", "name")
	assert_eq(smg.ammo, SMG.magazine_size, "magazine")
	assert_eq(smg.reserve, SMG.max_reserve, "reserve")
	assert_eq(player.hud.readout().ammo_text, "%d / %d" % [SMG.magazine_size, SMG.max_reserve], "HUD ammo")


func test_the_smg_fires_by_itself_while_fire_is_held() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	Input.action_press("fire")
	await run_seconds(0.5)
	Input.action_release("fire")
	var shots := SMG.magazine_size - smg.ammo
	assert_true(shots >= 5, "the held button fired %d shots in half a second" % shots)
	assert_true(shots <= int(0.5 / SMG.fire_interval) + 2, "the fire interval limits the shots, got %d" % shots)


func test_the_pistol_does_not_fire_by_itself_while_fire_is_held() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	Input.action_press("fire")
	await run_seconds(0.5)
	Input.action_release("fire")
	assert_eq(pistol.ammo, pistol.data.magazine_size - 1, "one press is one shot")


func test_the_smg_reload_takes_the_time_and_the_rounds_of_its_data() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	for _i: int in 10:
		await run_seconds(SMG.fire_interval + 0.02)
		smg.try_fire()
	var missing := SMG.magazine_size - smg.ammo
	assert_eq(missing, 10, "ten rounds were shot")
	smg.start_reload()
	await run_seconds(SMG.reload_time - 0.2)
	assert_true(smg.is_reloading(), "still reloading before the reload time")
	await run_seconds(0.4)
	assert_true(not smg.is_reloading(), "reload done after the reload time")
	assert_eq(smg.ammo, SMG.magazine_size, "magazine full")
	assert_eq(smg.reserve, SMG.max_reserve - missing, "the reserve paid for the reload")


func test_the_smg_reload_drops_the_magazine_and_the_left_hand_slaps_in_a_new_one() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	var view := smg.view_model as MagazineViewModel
	await run_seconds(1.0)
	var rest := view.model.global_transform
	smg.try_fire()
	await run_seconds(0.3)
	smg.start_reload()
	var magazine_was_out := false
	var left_hand_came := false
	for _i: int in ceili(SMG.reload_time * Engine.physics_ticks_per_second) + 10:
		await physics_frames(1)
		if not view.magazine.is_visible_in_tree():
			magazine_was_out = true
		if view.left_hand.is_visible_in_tree():
			left_hand_came = true
	assert_true(magazine_was_out, "the empty magazine leaves the gun")
	assert_true(left_hand_came, "the left hand brings the new magazine")
	var dropped: Array[ThrownGun] = []
	for child: Node in player.get_parent().get_children():
		if child is ThrownGun:
			dropped.append(child as ThrownGun)
	assert_eq(dropped.size(), 1, "one empty magazine dropped")
	assert_true(dropped[0].global_position.y < rest.origin.y - 0.3, "the empty magazine fell below the gun")
	assert_true(not smg.is_reloading(), "the reload is over")
	assert_true(view.magazine.is_visible_in_tree(), "a new magazine is in the gun")
	assert_true(not view.left_hand.is_visible_in_tree(), "the left hand is gone")
	await run_seconds(0.5)
	assert_true(view.model.global_transform.origin.distance_to(rest.origin) < 0.005, "the gun is back at rest")
	assert_true(view.hand.global_transform.is_equal_approx(view.model.global_transform), "the right hand holds the gun")


func test_switching_away_mid_reload_brings_the_smg_back_whole() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	var view := smg.view_model as MagazineViewModel
	smg.try_fire()
	await run_seconds(0.5)
	smg.start_reload()
	await run_seconds(SMG.reload_time * 0.5)
	player.switch_to(0)
	player.switch_to(1)
	await run_seconds(1.0)
	assert_true(view.magazine.is_visible_in_tree(), "the magazine is in the gun")
	assert_true(not view.left_hand.is_visible_in_tree(), "the left hand is gone")
	assert_true(view.hand.global_transform.is_equal_approx(view.model.global_transform), "the right hand holds the gun")
