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
