extends TestCase

const SMG: WeaponData = preload("res://weapons/smg.tres")
const THIRD: WeaponData = preload("res://weapons/pistol.tres")


func test_a_bought_weapon_is_in_hand_and_the_hud_shows_it() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	var smg := player.give_weapon(SMG)
	assert_true(player.weapon == smg, "the new weapon is in hand")
	assert_eq(player.weapons.size(), 2, "two weapons held")
	assert_eq(player.hud.readout().weapon_name, "SMG", "HUD name")
	assert_eq(player.hud.readout().ammo_text, "30 / 150", "HUD ammo")
	assert_true(not pistol.is_visible_in_tree(), "the pistol is out of sight")
	assert_true(smg.is_visible_in_tree(), "the SMG is in sight")


func test_keys_and_the_wheel_switch_the_weapon() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	var smg := player.give_weapon(SMG)
	var changes: Array[Weapon] = []
	player.weapon_changed.connect(changes.append)
	press_action(&"weapon_1")
	assert_true(player.weapon == pistol, "key 1 draws the pistol")
	assert_eq(player.hud.readout().weapon_name, "PISTOL", "HUD name after key 1")
	assert_eq(player.hud.readout().ammo_text, "12 / 48", "HUD ammo after key 1")
	press_action(&"weapon_2")
	assert_true(player.weapon == smg, "key 2 draws the SMG")
	press_action(&"weapon_next")
	assert_true(player.weapon == pistol, "wheel down goes to the next slot, and wraps")
	press_action(&"weapon_previous")
	assert_true(player.weapon == smg, "wheel up goes back")
	assert_eq(changes.size(), 4, "weapon_changed for each switch")
	press_action(&"weapon_2")
	assert_eq(changes.size(), 4, "the slot in hand is a no-op")


func test_a_player_with_one_weapon_does_not_switch() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	press_action(&"weapon_2")
	press_action(&"weapon_next")
	assert_true(player.weapon == pistol, "nothing to switch to")
	assert_true(pistol.is_visible_in_tree(), "the pistol stays in sight")


func test_a_holstered_weapon_does_not_fire() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	player.give_weapon(SMG)
	Input.action_press("fire")
	await run_seconds(0.3)
	assert_eq(pistol.ammo, pistol.data.magazine_size, "the holstered pistol did not fire")
	Input.action_release("fire")


func test_a_holstered_weapon_gives_up_its_reload() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	pistol.try_fire()
	pistol.start_reload()
	assert_true(player.hud.readout().reloading, "the reload shows")
	player.give_weapon(SMG)
	assert_true(not player.hud.readout().reloading, "the SMG does not reload")
	await run_seconds(pistol.data.reload_time + 0.2)
	assert_eq(pistol.ammo, pistol.data.magazine_size - 1, "no refill while holstered")
	assert_eq(pistol.reserve, pistol.data.max_reserve, "the reserve is unspent")
	press_action(&"weapon_1")
	assert_true(not pistol.is_reloading(), "the reload did not resume")
	assert_true(not player.hud.readout().reloading, "no reload label")
	assert_true(pistol.view_model.model.visible, "the pistol model is back after a cut reload")


func test_a_drawn_weapon_fires_and_the_other_ammo_stays() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	press_action(&"weapon_1")
	assert_true(player.weapon.try_fire(), "the pistol fires after the draw")
	assert_eq(smg.ammo, SMG.magazine_size, "the SMG magazine is unchanged")
	press_action(&"weapon_2")
	assert_eq(player.hud.readout().ammo_text, "30 / 150", "the SMG ammo shows again")


func test_the_inventory_never_holds_more_than_two_and_a_third_replaces_the_one_in_hand() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	var smg := player.give_weapon(SMG)
	press_action(&"weapon_1")
	var third := player.give_weapon(THIRD)
	await physics_frames(2)
	assert_eq(player.weapons.size(), 2, "still two weapons")
	assert_true(player.weapon == third, "the new weapon is in hand")
	assert_true(player.weapons.has(smg), "the SMG is kept")
	assert_true(not is_instance_valid(pistol), "the replaced weapon is freed")
	assert_eq(player.hud.readout().weapon_name, "PISTOL", "HUD shows the new weapon")


func test_a_dead_player_does_not_switch() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	player.give_weapon(SMG)
	press_action(&"weapon_1")
	Health.find_on(player).damage(1.0e6)
	press_action(&"weapon_2")
	assert_true(player.weapon == pistol, "no switch after death")


func test_third_person_hides_the_weapon_in_hand_after_a_switch() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	press_action(&"third_person")
	await physics_frames(2)
	assert_true(not smg.view_model.is_visible_in_tree(), "the SMG is hidden in third person")
	press_action(&"weapon_1")
	assert_true(not player.weapon.view_model.is_visible_in_tree(), "the pistol is hidden in third person")
	press_action(&"third_person")
	await physics_frames(2)
	assert_true(player.weapon.view_model.is_visible_in_tree(), "the pistol shows in first person")


func test_death_disables_the_trigger_of_the_weapon_in_hand() -> void:
	var player := await spawn_player()
	var smg := player.give_weapon(SMG)
	Health.find_on(player).damage(1.0e6)
	var ammo := smg.ammo
	Input.action_press("fire")
	await run_seconds(0.3)
	Input.action_release("fire")
	assert_eq(smg.ammo, ammo, "a dead player does not shoot")
