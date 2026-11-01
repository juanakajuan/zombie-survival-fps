extends TestCase

const FIRE: FireEffect = preload("res://effects/fire.tres")
const SMG: WeaponData = preload("res://weapons/smg.tres")
const TICK_DAMAGE := 5.0
const BODY_HEIGHT := 0.8


func test_a_fire_shot_burns_the_zombie_for_the_burn_time() -> void:
	var player := await spawn_player()
	var fire := _fire(2.5, TICK_DAMAGE)
	player.weapon.effect = fire
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -5.0))
	await physics_frames(2)
	var health := Health.find_on(zombie)
	assert_true(_shoot(player, zombie), "the shot fires")
	var shot_damage := health.max_health - health.current
	assert_true(shot_damage > 0.0, "the shot hurts")
	assert_eq(_burns_on(zombie), 1, "the hit lights one fire")
	assert_true(Burn.find_on(zombie).is_emitting(), "flames show")
	assert_eq(player.wallet.points, player.wallet.points_per_hit, "the shot pays one hit")

	await run_seconds(1.5)
	assert_almost_eq(health.current, health.max_health - shot_damage - TICK_DAMAGE, 0.001, "one tick after 1.5 s")
	await run_seconds(0.7)
	assert_almost_eq(health.current, health.max_health - shot_damage - 2.0 * TICK_DAMAGE, 0.001, "two ticks after 2.2 s")
	assert_eq(_burns_on(zombie), 1, "still burning")
	await run_seconds(1.0)
	assert_eq(_burns_on(zombie), 0, "the fire went out after the burn time")
	assert_almost_eq(health.current, health.max_health - shot_damage - 2.0 * TICK_DAMAGE, 0.001, "no damage after the fire")
	assert_eq(player.wallet.points, 3 * player.wallet.points_per_hit, "each tick pays one hit")


func test_a_burn_time_of_whole_ticks_deals_each_tick() -> void:
	var player := await spawn_player()
	var fire := _fire(1.0, TICK_DAMAGE)
	fire.tick_interval = 0.1
	player.weapon.effect = fire
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -5.0))
	await physics_frames(2)
	var health := Health.find_on(zombie)
	assert_true(_shoot(player, zombie), "the shot fires")
	var shot_damage := health.max_health - health.current
	await run_seconds(1.5)
	assert_eq(_burns_on(zombie), 0, "the fire went out")
	assert_almost_eq(health.current, health.max_health - shot_damage - 10.0 * TICK_DAMAGE, 0.001, "the tick at the end of the burn counts")


func test_a_second_hit_restarts_the_burn_and_does_not_add_one() -> void:
	var player := await spawn_player()
	player.weapon.effect = _fire(2.5, TICK_DAMAGE)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -5.0))
	await physics_frames(2)
	var health := Health.find_on(zombie)
	assert_true(_shoot(player, zombie), "the first shot fires")
	var shot_damage := health.max_health - health.current
	await run_seconds(1.5)
	assert_true(Burn.find_on(zombie).time_left() < 1.1, "the burn has run down")
	assert_true(_shoot(player, zombie), "the second shot fires")
	assert_eq(_burns_on(zombie), 1, "still one fire")
	assert_true(Burn.find_on(zombie).time_left() > 2.4, "the second hit restarted the time")

	await run_seconds(1.7)
	assert_eq(_burns_on(zombie), 1, "the fire outlasts the first burn time")
	assert_almost_eq(health.current, health.max_health - 2.0 * shot_damage - 3.0 * TICK_DAMAGE, 0.001, "one tick each second, no extra")


func test_a_fire_kill_pays_the_kill_bonus_and_no_headshot_bonus() -> void:
	var player := await spawn_player()
	player.weapon.effect = _fire(2.5, 500.0)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -5.0))
	await physics_frames(2)
	assert_true(_shoot(player, zombie), "the shot fires")
	assert_true(not zombie.is_dead(), "the shot alone does not kill")
	await run_seconds(1.5)
	assert_true(zombie.is_dead(), "the fire killed the zombie")
	assert_eq(_burns_on(zombie), 0, "a dead zombie does not burn")
	assert_eq(player.wallet.points, 2 * player.wallet.points_per_hit + player.wallet.kill_bonus, "a hit, then a hit with the kill bonus")


func test_a_burn_never_takes_the_legs() -> void:
	var player := await spawn_player()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -5.0))
	player.weapon.effect = _fire(2.5, zombie.leg_loss_damage + 10.0)
	await physics_frames(2)
	var health := Health.find_on(zombie)
	assert_true(_shoot(player, zombie), "the shot fires")
	await run_seconds(1.5)
	assert_true(not zombie.is_dead(), "the zombie lives through the tick")
	assert_true(health.current < health.max_health - zombie.leg_loss_damage, "the tick hurt more than a leg hit")
	assert_eq(zombie.gait, Zombie.Gait.WALK, "the zombie still walks")


func test_a_holstered_weapon_keeps_its_effect() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	pistol.effect = FIRE
	var smg := player.give_weapon(SMG)
	assert_true(pistol.effect == FIRE, "the holstered pistol keeps the effect")
	assert_true(smg.effect == null, "the new weapon has none")
	player.switch_to(0)
	assert_true(player.weapon == pistol and pistol.effect == FIRE, "the pistol has the effect in hand again")


func test_a_downed_player_fires_the_pistol_with_its_effect() -> void:
	var player := await spawn_player()
	var pistol := player.weapon
	pistol.effect = FIRE
	player.give_weapon(SMG)
	down_player(player)
	assert_true(player.weapon == pistol, "the held pistol is in hand")
	assert_true(player.weapon.effect == FIRE, "it keeps the effect")


func test_a_loaner_pistol_has_no_effect() -> void:
	var player := await spawn_player()
	player.max_weapons = 1
	player.give_weapon(SMG).effect = FIRE
	down_player(player)
	assert_eq(player.weapon.data, player.downed_weapon, "the loaner pistol is in hand")
	assert_true(player.weapon.effect == null, "it has no effect")


func _fire(burn_time: float, tick_damage: float) -> FireEffect:
	var fire := FIRE.duplicate() as FireEffect
	fire.burn_time = burn_time
	fire.tick_damage = tick_damage
	return fire


func _shoot(player: Player, zombie: Zombie) -> bool:
	look_at_point(player, zombie.global_position + Vector3.UP * BODY_HEIGHT)
	return player.weapon.try_fire()


func _burns_on(zombie: Zombie) -> int:
	return zombie.get_children().filter(func(child: Node) -> bool: return child is Burn).size()
