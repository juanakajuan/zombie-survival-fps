extends TestCase

const UPGRADE: UpgradeItem = preload("res://upgrades/upgrade.tres")
const UPGRADE_MACHINE_SCENE: PackedScene = preload("res://upgrades/upgrade_machine.tscn")
const POWER_SWITCH_SCENE: PackedScene = preload("res://perks/power_switch.tscn")
const SMG_ITEM: WeaponItem = preload("res://economy/smg_item.tres")


func test_the_upgrade_raises_damage_and_ammo_of_the_weapon_in_hand() -> void:
	var player := await spawn_player()
	var base := player.weapon.data
	var machine := _spawn_machine(null)
	player.wallet.add(UPGRADE.cost)
	assert_eq(machine.prompt_text(player), "E  BUY UPGRADE PISTOL  %d" % UPGRADE.cost, "prompt")
	assert_true(machine.buy(player), "the purchase succeeds")
	assert_eq(player.wallet.points, 0, "the cost was spent")
	var upgraded := player.weapon.data
	assert_true(upgraded == base.upgrade, "the upgraded pistol is in hand")
	assert_true(upgraded.damage > base.damage, "more damage")
	assert_eq(player.weapon.ammo, upgraded.magazine_size, "a full, larger magazine")
	assert_true(upgraded.magazine_size > base.magazine_size, "a larger magazine")
	assert_eq(player.weapon.reserve, upgraded.max_reserve, "a full, larger reserve")
	assert_true(upgraded.max_reserve > base.max_reserve, "a larger reserve")
	assert_eq(player.weapons.size(), 1, "the upgrade replaces the pistol")
	assert_eq(player.hud.readout().weapon_name, upgraded.display_name, "HUD name")

	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -5.0))
	var health := Health.find_on(dummy)
	await physics_frames(1)
	assert_true(player.weapon.try_fire(), "the upgraded pistol fires")
	assert_almost_eq(health.max_health - health.current, upgraded.damage, 0.001, "the shot deals the upgraded damage")


func test_the_first_purchase_upgrades_and_gives_no_effect() -> void:
	var player := await spawn_player()
	var machine := _spawn_machine(null)
	player.wallet.add(UPGRADE.cost + UPGRADE.effect_cost)
	assert_true(machine.buy(player), "the first purchase")
	assert_true(not player.effect_menu.is_open(), "the menu stays closed")
	assert_true(not get_tree().paused, "the game runs")
	assert_true(player.weapon.effect == null, "the weapon has no effect")
	assert_eq(player.wallet.points, UPGRADE.effect_cost, "only the first price was spent")


func test_a_weapon_with_the_first_upgrade_gets_an_effect_that_the_player_selects() -> void:
	var player := await spawn_player()
	var machine := _spawn_machine(null)
	player.wallet.add(UPGRADE.cost + UPGRADE.effect_cost)
	assert_true(machine.buy(player), "the first upgrade")
	var upgraded := player.weapon
	assert_eq(machine.prompt_text(player), "E  BUY UPGRADE %s  %d" % [upgraded.data.display_name, UPGRADE.effect_cost], "prompt")
	assert_true(machine.buy(player), "the second upgrade")
	assert_eq(player.wallet.points, 0, "the effect price was spent")
	assert_true(player.effect_menu.is_open(), "the menu opens")
	assert_true(get_tree().paused, "the game is paused")
	assert_true(player.weapon.effect == null, "no effect until the player selects one")
	assert_eq(player.hud.readout().weapon_effect, "", "no sign yet")
	assert_eq(player.effect_menu.effect_labels(), PackedStringArray(["FIRE"]), "the menu offers fire")

	player.effect_menu.select("FIRE")
	assert_true(player.weapon == upgraded, "the same weapon is in hand")
	assert_eq(player.weapon.effect.display_name, "FIRE", "the weapon has the effect")
	assert_eq(player.hud.readout().weapon_effect, "FIRE", "the HUD shows the effect")
	assert_true(not player.effect_menu.is_open(), "the menu closes")
	assert_true(not get_tree().paused, "the game runs again")


func test_the_effect_price_is_not_taken_without_the_points() -> void:
	var player := await spawn_player()
	var machine := _spawn_machine(null)
	player.wallet.add(UPGRADE.cost)
	assert_true(machine.buy(player), "the first upgrade")
	player.wallet.add(UPGRADE.effect_cost - 1)
	assert_true(not machine.buy(player), "one point short")
	assert_true(not player.effect_menu.is_open(), "no menu")
	assert_eq(player.wallet.points, UPGRADE.effect_cost - 1, "no points spent")


func test_the_effect_menu_has_no_cancel() -> void:
	var player := await spawn_player()
	player.wallet.add(UPGRADE.cost + UPGRADE.effect_cost)
	var machine := _spawn_machine(null)
	assert_true(machine.buy(player) and machine.buy(player), "both upgrades")
	press_action(&"ui_cancel")
	await physics_frames(2)
	assert_true(player.effect_menu.is_open(), "Esc leaves the menu open")
	assert_true(not player.pause_menu.is_open(), "the pause menu stays closed")
	assert_true(get_tree().paused, "the game stays paused")


func test_a_weapon_with_an_effect_cannot_be_upgraded_again() -> void:
	var player := await spawn_player()
	var machine := _spawn_machine(null)
	player.wallet.add(UPGRADE.cost + UPGRADE.effect_cost * 2)
	assert_true(machine.buy(player), "the first upgrade")
	assert_true(machine.buy(player), "the second upgrade")
	player.effect_menu.select("FIRE")
	var upgraded := player.weapon
	assert_eq(machine.prompt_text(player), "%s CANNOT BE UPGRADED" % upgraded.data.display_name, "prompt")
	assert_true(not machine.buy(player), "the third purchase fails")
	assert_eq(player.wallet.points, UPGRADE.effect_cost, "no points spent")
	assert_true(player.weapon == upgraded, "the weapon in hand did not change")
	assert_true(not player.effect_menu.is_open(), "no menu")


func test_a_weapon_with_no_upgrade_is_an_upgrade_of_another_weapon() -> void:
	var weapons: Array[WeaponData] = []
	for file: String in DirAccess.get_files_at("res://weapons"):
		if file.get_extension() != "tres":
			continue
		var data := load("res://weapons/%s" % file) as WeaponData
		if data != null:
			weapons.append(data)
	assert_true(weapons.size() > 1, "found the weapon data")
	for data: WeaponData in weapons:
		if data.upgrade == null:
			assert_true(weapons.any(func(other: WeaponData) -> bool: return other.upgrade == data), "%s has no upgrade, so it must be an upgrade" % data.display_name)


func test_the_machine_upgrades_only_with_power() -> void:
	var player := await spawn_player()
	var power := POWER_SWITCH_SCENE.instantiate() as PowerSwitch
	power.position = Vector3(3.0, 0.0, 0.0)
	add_child(power)
	var machine := _spawn_machine(power)
	var base := player.weapon.data
	player.wallet.add(UPGRADE.cost)
	assert_eq(machine.prompt_text(player), "NEEDS POWER", "prompt with no power")
	assert_true(not machine.buy(player), "no upgrade without power")
	assert_eq(player.wallet.points, UPGRADE.cost, "no points spent")
	assert_true(player.weapon.data == base, "the pistol is not upgraded")
	power.turn_on()
	assert_true(machine.buy(player), "the upgrade with power")
	assert_true(player.weapon.data == base.upgrade, "the pistol is upgraded")


func test_an_upgraded_weapon_keeps_its_slot_and_its_wall_station_sells_its_ammo() -> void:
	var player := await spawn_player()
	var station := spawn_station(Vector3(-3.0, 0.0, 0.0))
	station.item = SMG_ITEM
	var machine := _spawn_machine(null)
	player.wallet.add(SMG_ITEM.cost + UPGRADE.cost + SMG_ITEM.ammo_cost)
	assert_true(station.buy(player), "bought the SMG")
	assert_true(machine.buy(player), "upgraded the SMG")
	var smg := player.weapon
	assert_true(smg.data == SMG_ITEM.weapon.upgrade, "the upgraded SMG is in hand")
	assert_true(player.weapons[1] == smg, "the upgraded SMG is in the SMG's slot")
	assert_eq(station.prompt_text(player), "E  BUY SMG AMMO  %d" % SMG_ITEM.ammo_cost, "the station sells ammo, not a new SMG")
	smg.reserve = 0
	assert_true(station.buy(player), "bought ammo")
	assert_eq(smg.reserve, smg.data.max_reserve, "the ammo fills the larger reserve")
	assert_eq(player.weapons.size(), 2, "no new weapon")


func test_the_upgraded_gun_swaps_its_colors_and_keeps_its_ink() -> void:
	var player := await spawn_player()
	player.wallet.add(UPGRADE.cost)
	assert_true(_spawn_machine(null).buy(player), "upgraded the pistol")
	var swaps := player.weapon.data.view_materials
	assert_true(not swaps.is_empty(), "the upgraded data swaps materials")
	var swapped := 0
	for mesh: MeshInstance3D in player.weapon.view_model.model.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			var name := mesh.mesh.surface_get_material(surface).resource_name
			var shown := mesh.get_active_material(surface).resource_name
			if swaps.has(name):
				swapped += 1
				assert_eq(shown, swaps[name].resource_name, "%s shows the upgrade color" % mesh.name)
			else:
				assert_eq(shown, name, "%s keeps %s" % [mesh.name, name])
	assert_true(swapped > 0, "some surfaces show the upgrade colors")


func _spawn_machine(power: PowerSwitch) -> BuyStation:
	var machine := UPGRADE_MACHINE_SCENE.instantiate() as BuyStation
	machine.power = power
	machine.position = Vector3(0.0, 0.0, 3.0)
	add_child(machine)
	return machine
