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
	wallet.reward_hit(false)
	assert_eq(wallet.points, wallet.points_per_hit, "a hit")
	wallet.reward_hit(true)
	assert_eq(wallet.points, wallet.points_per_hit * 2 + wallet.kill_bonus, "a kill")


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
