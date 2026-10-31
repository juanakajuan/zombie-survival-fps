extends TestCase

const GRENADE_SCENE: PackedScene = preload("res://grenades/grenade.tscn")
const SETTLE_FRAMES := 5
const FAR := -20.0


func _tap_grenade() -> void:
	Input.action_press("grenade")
	await physics_frames(2)
	Input.action_release("grenade")


func _throw_grenade(player: Player) -> void:
	await _tap_grenade()
	await run_seconds(player.grenades.throw_wind_time + 0.1)


## A grenade that stays where it is, so the distances to the zombies are exact.
func _still_grenade(player: Player, at: Vector3, fuse_time: float = 0.2) -> Grenade:
	var grenade := GRENADE_SCENE.instantiate() as Grenade
	player.grenades.arm(grenade)
	grenade.freeze = true
	grenade.fuse_time = fuse_time
	grenade.position = at
	return grenade


func _still_zombie(at: Vector3) -> Zombie:
	return spawn_zombie(at)


func _damage_taken(zombie: Zombie) -> float:
	var health := Health.find_on(zombie)
	return health.max_health - health.current


func test_pressing_grenade_throws_one_along_the_aim() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	var before := player.grenades.count
	await _throw_grenade(player)
	assert_eq(player.grenades.count, before - 1, "a throw takes one grenade")
	assert_eq(thrown.size(), 1, "one grenade flies")
	await physics_frames(10)
	assert_true(thrown[0].global_position.z < -2.0, "the grenade flies away along the aim, at %s" % thrown[0].global_position)
	assert_almost_eq(Health.find_on(player).current, Health.find_on(player).max_health, 0.001, "the throw does not hurt the player")


func test_a_press_during_the_throw_does_nothing_and_one_after_it_throws() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	await _throw_grenade(player)
	await _tap_grenade()
	assert_eq(player.grenades.count, player.grenades.starting_count - 1, "the second press in the recovery takes no grenade")
	await run_seconds(player.grenades.throw_recover_time + player.grenades.throw_wind_time)
	await _throw_grenade(player)
	assert_eq(thrown.size(), 2, "a press after the recovery throws")


func test_with_no_grenades_a_press_throws_nothing() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.grenades.count = 0
	var thrown: Array[Grenade] = []
	player.grenades.thrown.connect(thrown.append)
	await _throw_grenade(player)
	assert_eq(thrown.size(), 0, "no grenade flies")
	assert_eq(player.grenades.count, 0, "the count stays at 0")


func test_a_dead_player_does_not_throw() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Health.find_on(player).damage(1.0e6)
	var before := player.grenades.count
	assert_true(not player.grenades.start_cook(), "no cook")
	await _throw_grenade(player)
	assert_eq(player.grenades.count, before, "the press takes no grenade")


func test_the_blast_waits_for_the_fuse() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, FAR - 1.0))
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, FAR), 0.5)
	var blasts := [0]
	grenade.exploded.connect(func() -> void: blasts[0] += 1)
	add_child(grenade)
	await run_seconds(0.3)
	assert_eq(blasts[0], 0, "no blast before the fuse ends")
	assert_almost_eq(_damage_taken(zombie), 0.0, 0.001, "no damage before the fuse ends")
	await run_seconds(0.4)
	assert_eq(blasts[0], 1, "one blast after the fuse")
	assert_true(_damage_taken(zombie) > 0.0, "the zombie is hurt by the blast")


func test_damage_falls_with_the_distance_and_stops_at_the_radius() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var near := _still_zombie(Vector3(0.0, 0.0, FAR - 1.0))
	var far := _still_zombie(Vector3(0.0, 0.0, FAR - 3.0))
	var outside := _still_zombie(Vector3(0.0, 0.0, FAR - 8.0))
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, FAR))
	grenade.max_damage = 80.0
	grenade.min_damage = 10.0
	add_child(grenade)
	await run_seconds(0.4)
	var expected_near := lerpf(80.0, 10.0, 1.0 / grenade.blast_radius)
	var expected_far := lerpf(80.0, 10.0, 3.0 / grenade.blast_radius)
	assert_almost_eq(_damage_taken(near), expected_near, 1.0, "the near zombie takes the damage of its distance")
	assert_almost_eq(_damage_taken(far), expected_far, 1.0, "the far zombie takes the damage of its distance")
	assert_true(_damage_taken(near) > _damage_taken(far), "the closer zombie takes more")
	assert_almost_eq(_damage_taken(outside), 0.0, 0.001, "a zombie outside the radius is unharmed")


func test_a_zombie_hit_by_the_blast_is_hurt_once() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	_still_zombie(Vector3(0.0, 0.0, FAR - 1.0))
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, FAR))
	var reports: Array[bool] = []
	grenade.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: reports.append(headshot))
	add_child(grenade)
	await run_seconds(0.4)
	assert_eq(reports, [false] as Array[bool], "one report, and it is not a headshot")


func test_a_kill_by_a_grenade_pays_a_hit_and_the_kill_bonus() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, FAR - 1.0))
	add_child(_still_grenade(player, Vector3(0.0, 0.1, FAR)))
	await run_seconds(0.4)
	assert_true(Health.find_on(zombie).is_dead(), "the blast kills a round 1 zombie near the centre")
	assert_eq(player.wallet.points, player.wallet.points_per_hit + player.wallet.kill_bonus, "a hit and the kill bonus")
	var readout := player.hud.readout()
	assert_eq(readout.points_text, str(player.wallet.points), "the HUD shows the points")


func test_a_blast_that_wounds_pays_only_the_hit() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var zombie := _still_zombie(Vector3(0.0, 0.0, FAR - 3.0))
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, FAR))
	grenade.max_damage = 40.0
	grenade.min_damage = 10.0
	add_child(grenade)
	await run_seconds(0.4)
	assert_true(not Health.find_on(zombie).is_dead(), "the zombie lives")
	assert_eq(player.wallet.points, player.wallet.points_per_hit, "a hit and no bonus")


func test_insta_kill_makes_a_grenade_hit_a_kill() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	player.debug_menu.run_command("GIVE INSTA-KILL")
	var zombie := _still_zombie(Vector3(0.0, 0.0, FAR - 3.0))
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, FAR))
	grenade.max_damage = 20.0
	grenade.min_damage = 10.0
	add_child(grenade)
	await run_seconds(0.4)
	assert_true(Health.find_on(zombie).is_dead(), "a weak blast kills under insta-kill")
	assert_eq(player.wallet.points, (player.wallet.points_per_hit + player.wallet.kill_bonus) * player.wallet.multiplier, "the kill pays as usual")


func test_the_blast_hurts_the_player_by_the_damage_scale() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var health := Health.find_on(player)
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, -1.0))
	grenade.max_damage = 60.0
	grenade.min_damage = 10.0
	grenade.player_damage_scale = 0.5
	var reports := [0]
	grenade.damaged.connect(func(_target: Node, _killed: bool, _headshot: bool) -> void: reports[0] += 1)
	add_child(grenade)
	await run_seconds(0.4)
	var expected := lerpf(60.0, 10.0, 1.0 / grenade.blast_radius) * 0.5
	assert_almost_eq(health.max_health - health.current, expected, 1.0, "the player takes the scaled damage")
	assert_eq(reports[0], 0, "the player's own damage is not a hit")
	assert_eq(player.wallet.points, 0, "the player's own damage pays nothing")


func test_a_damage_scale_of_zero_never_hurts_the_player() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var health := Health.find_on(player)
	var grenade := _still_grenade(player, Vector3(0.0, 0.1, -1.0))
	grenade.player_damage_scale = 0.0
	add_child(grenade)
	await run_seconds(0.4)
	assert_almost_eq(health.current, health.max_health, 0.001, "the player is unharmed")


func test_a_new_round_adds_grenades_up_to_the_maximum() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var grenades := player.grenades
	var counts: Array[int] = []
	grenades.changed.connect(counts.append)
	grenades.count = 0
	grenades.start_round()
	assert_eq(grenades.count, grenades.per_round, "a round adds per_round")
	grenades.count = grenades.max_count - 1
	grenades.start_round()
	assert_eq(grenades.count, grenades.max_count, "a round never goes above the maximum")
	grenades.start_round()
	assert_eq(grenades.count, grenades.max_count, "a round at the maximum adds none")
	assert_eq(counts, [grenades.per_round, grenades.max_count] as Array[int], "changed reports each change")


func test_the_hud_shows_the_count() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	assert_eq(player.hud.readout().grenades_text, str(player.grenades.starting_count), "the HUD starts with the starting count")
	await _throw_grenade(player)
	assert_eq(player.hud.readout().grenades_text, str(player.grenades.starting_count - 1), "the HUD follows a throw")


func test_the_level_gives_grenades_at_the_start_of_the_next_round() -> void:
	var level := await spawn_level()
	var grenades := level.player.grenades
	assert_eq(grenades.count, grenades.starting_count, "round 1 starts with the starting count")
	grenades.count = 1
	level.round_manager.kill_all()
	level.round_manager.skip_break()
	await physics_frames(2)
	assert_eq(grenades.count, mini(1 + grenades.per_round, grenades.max_count), "round 2 adds grenades")
	assert_eq(level.player.hud.readout().grenades_text, str(grenades.count), "the HUD shows them")
