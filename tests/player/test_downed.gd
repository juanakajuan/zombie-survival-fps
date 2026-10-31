extends TestCase

const SMG: WeaponData = preload("res://weapons/smg.tres")
const SECOND_WIND: PerkItem = preload("res://perks/second_wind.tres")
const IRON_GUT: PerkItem = preload("res://perks/iron_gut.tres")
const SETTLE_FRAMES := 10

var _self_revive := PerkItem.new()


func test_without_a_self_revive_perk_zero_health_kills_at_once() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var counts: Array[int] = [0, 0]
	player.downed.connect(func() -> void: counts[0] += 1)
	player.died.connect(func() -> void: counts[1] += 1)
	player.health.damage(player.health.max_health)
	assert_true(player.is_dead(), "is_dead")
	assert_true(not player.is_downed(), "not downed")
	assert_eq(counts[0], 0, "downed does not emit")
	assert_eq(counts[1], 1, "died emits once")


func test_zero_health_downs_the_player() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var counts: Array[int] = [0, 0]
	player.downed.connect(func() -> void: counts[0] += 1)
	player.died.connect(func() -> void: counts[1] += 1)
	var stand_height := player.camera.global_position.y
	_down(player)
	await run_seconds(0.5)
	assert_true(player.is_downed(), "is_downed")
	assert_true(not player.is_dead(), "not dead")
	assert_eq(counts[0], 1, "downed emits once")
	assert_eq(counts[1], 0, "died does not emit")
	assert_true(player.camera.global_position.y < stand_height - 0.5, "the camera is low, got %s" % player.camera.global_position.y)
	var readout := player.hud.readout()
	assert_true(readout.downed_visible, "the HUD shows the timer")
	assert_true(readout.downed_text.begins_with("DOWNED"), "timer text, got %s" % readout.downed_text)


func test_downed_player_moves_slowly_and_cannot_jump() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_down(player)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await run_seconds(1.0)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(speed, player.downed_speed, 0.2, "speed is downed_speed")
	assert_true(not player.is_sprinting(), "not sprinting")
	Input.action_press("jump")
	await physics_frames(3)
	assert_true(player.is_on_floor(), "the jump does nothing")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "feet stay on the floor")


func test_downed_player_fires_a_full_pistol() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.weapon.ammo = 3
	_down(player)
	assert_eq(player.weapon.data, player.downed_weapon, "the pistol is in hand")
	assert_eq(player.weapon.ammo, player.weapon.data.magazine_size, "full magazine")
	assert_true(player.weapon.try_fire(), "the pistol fires")
	assert_eq(player.weapon.ammo, player.weapon.data.magazine_size - 1, "ammo goes down")


func test_downed_player_holsters_another_weapon_for_the_held_pistol() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var pistol := player.weapon
	var smg := player.give_weapon(SMG)
	pistol.ammo = 2
	_down(player)
	assert_true(player.weapon == pistol, "the held pistol is in hand")
	assert_eq(pistol.ammo, pistol.data.magazine_size, "full magazine")
	assert_true(not smg.visible, "the SMG is holstered")
	assert_eq(player.weapons.size(), 2, "the player holds the same two weapons")


func test_downed_player_without_a_pistol_gets_a_temporary_one() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.max_weapons = 1
	var smg := player.give_weapon(SMG)
	assert_eq(player.weapons.size(), 1, "the SMG replaced the pistol")
	_down(player)
	assert_eq(player.weapon.data, player.downed_weapon, "a pistol is in hand")
	assert_eq(player.weapon.ammo, player.weapon.data.magazine_size, "full magazine")
	assert_eq(player.weapons.size(), 1, "the pistol is not one of the held weapons")
	assert_true(player.weapon.try_fire(), "the pistol fires")
	player.revive(0.5)
	await physics_frames(2)
	assert_true(player.weapon == smg, "the SMG is back in hand")
	assert_eq(player.hud.readout().weapon_name, "SMG", "HUD weapon name")


func test_weapon_switch_does_nothing_while_downed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.give_weapon(SMG)
	_down(player)
	var pistol := player.weapon
	press_action(&"weapon_2")
	press_action(&"weapon_next")
	assert_true(player.weapon == pistol, "the pistol stays in hand")
	assert_true(not player.melee.try_swing(), "no punch while downed")


func test_downed_time_ends_in_death() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.downed_time = 0.5
	var counts: Array[int] = [0]
	player.died.connect(func() -> void: counts[0] += 1)
	_down(player)
	await run_seconds(0.3)
	assert_eq(counts[0], 0, "alive before the time ends")
	await run_seconds(0.4)
	assert_eq(counts[0], 1, "died emits once")
	assert_true(player.is_dead(), "is_dead")
	assert_true(not player.is_downed(), "not downed")
	assert_true(not player.hud.readout().downed_visible, "the HUD timer is hidden")
	var low := player.camera.global_position.y
	await run_seconds(0.5)
	assert_almost_eq(player.camera.global_position.y, low, 0.01, "the dead player stays on the ground")


func test_the_hud_tells_a_downed_player_when_the_perk_stands_them_up() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.perks.add(SECOND_WIND)
	player.health.damage(player.health.max_health)
	await run_seconds(0.5)
	var readout := player.hud.readout()
	assert_true(readout.revive_visible, "the HUD shows the self-revive line")
	assert_eq(readout.revive_text, "SECOND WIND  GETTING UP IN %d" % ceili(SECOND_WIND.self_revive_time - 0.5), "self-revive text")
	await run_seconds(SECOND_WIND.self_revive_time)
	assert_true(not player.is_downed(), "the perk stood the player up")
	assert_true(not player.hud.readout().revive_visible, "the self-revive line is hidden")


func test_revive_stands_the_player_up() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.downed_time = 0.5
	var smg := player.give_weapon(SMG)
	var stand_height := player.camera.global_position.y
	_down(player)
	await run_seconds(0.3)
	player.revive(0.5)
	await run_seconds(0.5)
	assert_true(not player.is_downed(), "not downed")
	assert_true(not player.is_dead(), "not dead")
	assert_almost_eq(player.health.current, player.health.max_health * 0.5, 0.01, "half health")
	assert_true(player.weapon == smg, "the SMG is back in hand")
	assert_almost_eq(player.camera.global_position.y, stand_height, 0.05, "the camera is up")
	assert_true(not player.hud.readout().downed_visible, "the HUD timer is hidden")
	await run_seconds(0.5)
	assert_true(not player.is_dead(), "the old timer does not kill the player")


func test_full_health_revives_and_zero_health_downs_again() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_down(player)
	player.health.reset()
	assert_true(not player.is_downed(), "the health reset stands the player up")
	_down(player)
	assert_true(player.is_downed(), "downed again at 0 health")


func test_revive_does_nothing_unless_downed() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.health.damage(40.0)
	player.revive(1.0)
	assert_almost_eq(player.health.current, 60.0, 0.01, "health stays")


func test_zombie_keeps_attacking_a_downed_player() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_interval = 0.3
	_down(player)
	await run_seconds(1.0)
	assert_eq(zombie.state, Zombie.State.ATTACK, "the zombie attacks the downed player")
	player.revive(0.5)
	await run_seconds(1.0)
	assert_true(player.health.current < player.health.max_health * 0.5, "the zombie hits the revived player")


func test_second_wind_stands_the_player_up_after_its_time() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.perks.add(SECOND_WIND)
	player.health.damage(player.health.max_health)
	assert_true(player.is_downed(), "downed")
	await run_seconds(SECOND_WIND.self_revive_time - 0.2)
	assert_true(player.is_downed(), "still downed just before the revive time")
	await run_seconds(0.4)
	assert_true(not player.is_downed(), "not downed after the revive time")
	assert_true(not player.is_dead(), "not dead")
	assert_almost_eq(player.health.current, player.health.max_health * SECOND_WIND.self_revive_health, 0.01, "revive health")
	assert_true(not player.hud.readout().downed_visible, "the HUD timer is hidden")


func test_going_down_loses_every_perk() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var start_max := player.health.max_health
	player.perks.add(IRON_GUT)
	player.perks.add(SECOND_WIND)
	player.health.damage(player.health.max_health)
	assert_true(player.perks.held.is_empty(), "no perk held")
	assert_almost_eq(player.health.max_health, start_max, 0.01, "the IRON GUT bonus is gone")
	assert_true(player.hud.readout().perk_icons.is_empty(), "the HUD shows no perk icon")


func test_the_revive_uses_up_second_wind() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.perks.add(SECOND_WIND)
	player.health.damage(player.health.max_health)
	await run_seconds(SECOND_WIND.self_revive_time + 0.2)
	assert_true(not player.is_downed(), "stood up")
	player.health.damage(player.health.max_health)
	assert_true(player.is_dead(), "with the perk used up, 0 health kills")


## A self-revive slower than downed_time, so that these tests see the downed state end in death.
func _down(player: Player) -> void:
	_self_revive.self_revive_time = 30.0
	if player.perks.can_add(_self_revive):
		player.perks.add(_self_revive)
	player.health.damage(player.health.max_health)
