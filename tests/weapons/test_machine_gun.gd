extends TestCase

const MACHINE_GUN: WeaponData = preload("res://weapons/machine_gun.tres")
const SMG: WeaponData = preload("res://weapons/smg.tres")


func test_the_machine_gun_fires_its_large_magazine_while_fire_is_held() -> void:
	var player := await spawn_player()
	var machine_gun := player.give_weapon(MACHINE_GUN)
	await run_seconds(1.0)
	assert_true(MACHINE_GUN.magazine_size > SMG.magazine_size, "the magazine is larger than the SMG's")
	Input.action_press("fire")
	await run_seconds(2.0)
	Input.action_release("fire")
	var shots := MACHINE_GUN.magazine_size - machine_gun.ammo
	assert_true(shots >= int(2.0 / MACHINE_GUN.fire_interval) - 2, "the held button kept firing, got %d shots" % shots)
	assert_true(machine_gun.ammo > 0, "two seconds do not empty the magazine")
	assert_true(not machine_gun.is_reloading(), "no reload while rounds are left")


func test_the_machine_gun_reload_is_slow() -> void:
	var player := await spawn_player()
	var machine_gun := player.give_weapon(MACHINE_GUN)
	await run_seconds(1.0)
	machine_gun.try_fire()
	machine_gun.start_reload()
	assert_true(MACHINE_GUN.reload_time > SMG.reload_time * 2.0, "the reload takes more than twice the SMG's")
	await run_seconds(MACHINE_GUN.reload_time - 0.2)
	assert_true(machine_gun.is_reloading(), "still reloading just before the reload time")
	await run_seconds(0.4)
	assert_true(not machine_gun.is_reloading(), "the reload is done after the reload time")
	assert_eq(machine_gun.ammo, MACHINE_GUN.magazine_size, "the magazine is full")


func test_the_upgraded_machine_gun_has_more_damage_and_ammo_and_a_faster_reload() -> void:
	var player := await spawn_player()
	player.give_weapon(MACHINE_GUN)
	player.upgrade_weapon()
	var upgraded := player.weapon.data
	assert_true(upgraded == MACHINE_GUN.upgrade, "the upgraded machine gun is in hand")
	assert_true(upgraded.damage > MACHINE_GUN.damage, "more damage")
	assert_true(upgraded.automatic, "still automatic")
	assert_true(upgraded.magazine_size > MACHINE_GUN.magazine_size, "a larger magazine")
	assert_true(upgraded.max_reserve > MACHINE_GUN.max_reserve, "a larger reserve")
	assert_true(upgraded.reload_time < MACHINE_GUN.reload_time, "a faster reload")
	assert_true(upgraded.upgrade == null, "the upgraded machine gun cannot be upgraded again")
