extends TestCase


func test_add_raises_the_balance_and_emits_changed() -> void:
	var player := await spawn_player()
	var seen: Array[int] = []
	player.wallet.changed.connect(func(points: int) -> void: seen.append(points))
	player.wallet.add(30)
	assert_eq(player.wallet.points, 30, "balance")
	assert_eq(seen, [30] as Array[int], "changed reports the new balance")


func test_spend_takes_the_cost_when_there_are_enough_points() -> void:
	var player := await spawn_player()
	player.wallet.add(100)
	assert_true(player.wallet.spend(40), "spend succeeds")
	assert_eq(player.wallet.points, 60, "balance after spend")


func test_spend_with_too_few_points_changes_nothing() -> void:
	var player := await spawn_player()
	player.wallet.add(10)
	var seen: Array[int] = []
	player.wallet.changed.connect(func(points: int) -> void: seen.append(points))
	assert_true(not player.wallet.spend(11), "spend fails")
	assert_eq(player.wallet.points, 10, "balance unchanged")
	assert_true(seen.is_empty(), "no changed signal")


func test_reward_hit_adds_the_kill_bonus_only_for_a_kill() -> void:
	var player := await spawn_player()
	var wallet := player.wallet
	wallet.reward_hit(false, false)
	assert_eq(wallet.points, wallet.points_per_hit, "a hit")
	wallet.reward_hit(true, false)
	assert_eq(wallet.points, wallet.points_per_hit * 2 + wallet.kill_bonus, "a kill")


func test_reward_hit_adds_the_headshot_bonus_only_for_a_headshot_kill() -> void:
	var player := await spawn_player()
	var wallet := player.wallet
	wallet.reward_hit(false, true)
	assert_eq(wallet.points, wallet.points_per_hit, "a headshot that does not kill pays the hit only")
	wallet.reward_hit(true, true)
	assert_eq(wallet.points, wallet.points_per_hit * 2 + wallet.kill_bonus + wallet.headshot_bonus, "a headshot kill")


func test_wallet_starts_with_starting_points() -> void:
	var wallet := Wallet.new()
	wallet.starting_points = 25
	add_child(wallet)
	assert_eq(wallet.points, 25, "starting balance")


func test_player_starts_with_no_points() -> void:
	var player := await spawn_player()
	assert_eq(player.wallet.points, 0, "starting balance")


func test_shooting_a_zombie_gives_points_per_hit() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -4.0), player)
	await physics_frames(2)
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_eq(player.wallet.points, player.wallet.points_per_hit, "points for one hit")
	assert_true(not zombie.is_dead(), "the zombie survives one shot")


func test_killing_a_zombie_adds_the_kill_bonus() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -4.0), player)
	await physics_frames(2)
	var health := Health.find_on(zombie)
	health.damage(health.max_health - player.weapon.data.damage)
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_true(zombie.is_dead(), "the shot kills the zombie")
	assert_eq(player.wallet.points, player.wallet.points_per_hit + player.wallet.kill_bonus, "points for the kill")


func test_shooting_a_dummy_gives_no_points() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	await spawn_dummy(Vector3(0.0, 0.0, -4.0))
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_eq(player.wallet.points, 0, "dummies give no points")


func _still_zombie(at: Vector3, player: Player) -> Zombie:
	var zombie := spawn_zombie(at, player)
	zombie.move_speed = 0.0
	return zombie


func test_shooting_a_dead_zombie_gives_no_points() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -4.0), player)
	await physics_frames(2)
	Health.find_on(zombie).damage(1.0e6)
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_eq(player.wallet.points, 0, "a corpse gives no points")


func test_a_boost_multiplies_hit_and_board_points_until_it_ends() -> void:
	var player := await spawn_player()
	var wallet := player.wallet
	wallet.boost(2, 1.0)
	wallet.reward_hit(true, true)
	var kill := (wallet.points_per_hit + wallet.kill_bonus + wallet.headshot_bonus) * 2
	assert_eq(wallet.points, kill, "a boosted headshot kill")
	wallet.reward_board()
	assert_eq(wallet.points, kill + wallet.points_per_board * 2, "a boosted board")
	await run_seconds(1.2)
	assert_eq(wallet.multiplier, 1, "the boost has ended")
	wallet.reward_hit(false, false)
	assert_eq(wallet.points, kill + wallet.points_per_board * 2 + wallet.points_per_hit, "a hit after the boost")


func test_a_boost_does_not_multiply_added_points_or_the_board_limit() -> void:
	var player := await spawn_player()
	var wallet := player.wallet
	wallet.boost(2, 30.0)
	wallet.add(500)
	assert_eq(wallet.points, 500, "add is not boosted")
	for _i: int in 20:
		wallet.reward_board()
	assert_eq(wallet.points, 500 + wallet.board_points_per_round * 2, "the limit counts points before the boost")


func test_a_new_boost_restarts_the_time() -> void:
	var player := await spawn_player()
	var wallet := player.wallet
	wallet.boost(2, 1.0)
	await run_seconds(0.8)
	wallet.boost(2, 1.0)
	await run_seconds(0.8)
	assert_eq(wallet.multiplier, 2, "the boost still runs")
	assert_almost_eq(wallet.boost_time_left(), 0.2, 0.05, "time left")
