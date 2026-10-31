extends TestCase

const GRENADE_SCENE: PackedScene = preload("res://grenades/grenade.tscn")
const SETTLE_FRAMES := 5
const FRAME_MARGIN := 3
const TIMING_TOLERANCE := 0.1

var _self_revive := PerkItem.new()
var _released_at: int = 0


## Holds the grenade key for `hold` seconds, then releases it. Returns the grenade once it leaves the hand.
func _cook_and_release(player: Player, hold: float) -> Grenade:
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	Input.action_press("grenade")
	await run_seconds(hold)
	Input.action_release("grenade")
	_released_at = Engine.get_physics_frames()
	for _i: int in roundi(2.0 * Engine.physics_ticks_per_second):
		if not thrown.is_empty():
			break
		await physics_frames(1)
	assert_eq(thrown.size(), 1, "the grenade leaves the hand")
	return thrown[0] if not thrown.is_empty() else null


## The seconds from the key release to the blast of this grenade.
func _seconds_to_blast(grenade: Grenade) -> float:
	while not grenade.has_exploded() and Engine.get_physics_frames() - _released_at < 6 * Engine.physics_ticks_per_second:
		await physics_frames(1)
	return float(Engine.get_physics_frames() - _released_at) / Engine.physics_ticks_per_second


func _down(player: Player) -> void:
	_self_revive.self_revive_time = 30.0
	if player.perks.can_add(_self_revive):
		player.perks.add(_self_revive)
	player.health.damage(player.health.max_health)


func test_a_tap_throws_a_grenade_along_the_aim_that_explodes_after_the_fuse() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var before := player.grenades.count
	var hold := 0.05
	var grenade := await _cook_and_release(player, hold)
	assert_eq(player.grenades.count, before - 1, "a throw takes one grenade")
	await physics_frames(10)
	assert_true(grenade.global_position.z < -2.0, "the grenade flies along the aim, at %s" % grenade.global_position)
	var seconds := await _seconds_to_blast(grenade)
	assert_almost_eq(seconds, grenade.fuse_time - hold, TIMING_TOLERANCE, "the blast comes a fuse after the press")


func test_a_cooked_grenade_explodes_sooner_by_the_time_it_was_held() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var hold := 1.0
	var grenade := await _cook_and_release(player, hold)
	var seconds := await _seconds_to_blast(grenade)
	assert_almost_eq(seconds, grenade.fuse_time - hold, TIMING_TOLERANCE, "the blast comes the fuse less the cook after the release")


func test_a_grenade_held_past_its_fuse_explodes_in_the_hand() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -2.0))
	var health := Health.find_on(player)
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	var before := player.grenades.count
	var reference := GRENADE_SCENE.instantiate() as Grenade
	Input.action_press("grenade")
	await run_seconds(reference.fuse_time + 0.3)
	var aim := player.aim_transform()
	var hand := aim.origin + aim.basis * player.grenades.hand_offset
	var expected := lerpf(reference.max_damage, reference.min_damage, hand.distance_to(player.global_position) / reference.radius) * reference.player_damage_scale
	reference.free()
	assert_eq(thrown.size(), 0, "no grenade flies")
	assert_eq(player.grenades.count, before - 1, "the grenade is spent")
	assert_true(not player.is_throwing(), "the player is free again")
	assert_almost_eq(health.max_health - health.current, expected, 1.0, "the player takes the scaled damage")
	assert_true(Health.find_on(zombie).is_dead(), "the zombie near the player dies")


func test_the_gun_and_the_fist_wait_while_a_grenade_is_in_hand() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.weapon.ammo = 3
	var swings := [0]
	player.melee.swung.connect(func() -> void: swings[0] += 1)
	Input.action_press("grenade")
	await run_seconds(player.grenades.cook_raise_time + 0.1)
	assert_true(player.is_throwing(), "the grenade is cooking")
	Input.action_press("fire")
	Input.action_press("reload")
	await physics_frames(10)
	Input.action_release("fire")
	Input.action_release("reload")
	assert_eq(player.weapon.ammo, 3, "the gun does not fire")
	assert_true(not player.weapon.is_reloading(), "the gun does not reload")
	Input.action_press("melee")
	await physics_frames(FRAME_MARGIN)
	Input.action_release("melee")
	assert_eq(swings[0], 0, "the player does not punch")
	Input.action_release("grenade")
	await run_seconds(player.grenades.throw_wind_time + player.grenades.throw_recover_time + 0.1)
	assert_true(player.weapon.try_fire(), "the gun fires again after the throw")


func test_a_grenade_does_not_start_during_a_punch() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("melee")
	await physics_frames(FRAME_MARGIN)
	Input.action_release("melee")
	assert_true(player.is_meleeing(), "the punch is on")
	Input.action_press("grenade")
	await physics_frames(FRAME_MARGIN)
	assert_true(not player.is_throwing(), "no grenade starts")
	assert_eq(player.grenades.count, player.grenades.starting_count, "no grenade is spent")


func test_the_hand_shows_while_cooking_and_throwing_and_hides_after() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var view := player.grenade_view
	assert_true(not view.is_hand_visible(), "hidden while ready")
	Input.action_press("grenade")
	await physics_frames(FRAME_MARGIN)
	assert_true(view.is_hand_visible(), "shown while cooking")
	assert_true(view.is_grenade_visible(), "the grenade is in the hand while cooking")
	Input.action_release("grenade")
	await run_seconds(player.grenades.throw_wind_time + 0.05)
	assert_true(view.is_hand_visible(), "the hand follows through after the throw")
	assert_true(not view.is_grenade_visible(), "the grenade has left the hand")
	await run_seconds(player.grenades.throw_recover_time + 0.05)
	assert_true(not view.is_hand_visible(), "hidden after the throw")


func test_a_player_who_goes_down_while_cooking_drops_the_grenade_at_the_feet() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	Input.action_press("grenade")
	await run_seconds(0.5)
	_released_at = Engine.get_physics_frames()
	_down(player)
	assert_true(player.is_downed(), "the player is down")
	assert_true(not player.is_throwing(), "the cook is over")
	assert_eq(thrown.size(), 1, "the grenade drops")
	assert_true(thrown[0].global_position.distance_to(player.global_position) < 0.5, "it lies at the feet, at %s" % thrown[0].global_position)
	var seconds := await _seconds_to_blast(thrown[0])
	assert_almost_eq(seconds, thrown[0].fuse_time - 0.5, TIMING_TOLERANCE, "it still explodes when the fuse ends")


func test_the_hud_shows_the_fuse_while_cooking_and_nothing_after() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	assert_eq(player.hud.readout().grenade_fuse_text, "", "no fuse while ready")
	Input.action_press("grenade")
	await run_seconds(0.5)
	var fuse := player.hud.readout().grenade_fuse_text.to_float()
	var reference := GRENADE_SCENE.instantiate() as Grenade
	assert_almost_eq(fuse, reference.fuse_time - 0.5, 0.15, "the HUD shows the fuse that is left")
	reference.free()
	Input.action_release("grenade")
	await run_seconds(player.grenades.throw_wind_time + player.grenades.throw_recover_time + 0.1)
	assert_eq(player.hud.readout().grenade_fuse_text, "", "no fuse after the throw")
